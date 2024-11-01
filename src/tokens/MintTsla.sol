// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/dev/v1_X/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/dev/v1_X/libraries/FunctionsRequest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {OracleLib} from "src/libaries/OracleLib.sol";
import {AggregatorV3Interface} from "src/libaries/OracleLib.sol";
import {TokenPrice} from "../PriceFeed.sol";
import {IGetTslaReturnTypes} from "../interfaces/ReturnType.sol";

/**
 * @title TokenBizz
 * @notice This is our contract to make requests to the Alpaca API to mint TSLA-backed dTSLA tokens
 * @dev This contract is meant to be for educational purposes only
 */
contract MintTsla is FunctionsClient, ConfirmedOwner, ERC20, Pausable, IGetTslaReturnTypes {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;
    using OracleLib for AggregatorV3Interface;

    error dTSLA__NotEnoughCollateral();
    error dTSLA__BelowMinimumRedemption();

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    struct dTslaRequest {
        uint256 amountOfToken;
        address requester;
    }

    TokenPrice tokenPrice =
        new TokenPrice(returnType.functionsRouter, returnType.donId, returnType.subId, returnType.priceSource);

    GetTokenBizzReturnType private returnType;

    uint256 s_portfolioBalance;

    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
    mapping(address user => uint256 amountAvailableForWithdrawal) private s_userToWithdrawalAmount;

    uint256 public constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 100e18;
    uint32 private constant GAS_LIMIT = 300_000;

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PORTFOLIO_PRECISION = 1e18;
    uint256 public constant COLLATERAL_RATIO = 300; // 200% collateral ratio
    uint256 public constant COLLATERAL_PRECISION = 200;
    address constant USDC_CONTRACT = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    uint256 private constant TARGET_DECIMALS = 18;
    uint256 private constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Response(bytes32 indexed requestId, uint256 character, bytes response, bytes err);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(GetTokenBizzReturnType memory _returnType)
        FunctionsClient(_returnType.functionsRouter)
        ConfirmedOwner(msg.sender)
        ERC20("Backed TSLA", "bTSLA")
    {
        returnType = _returnType;
    }

    function sendMintTSLARequest(uint256 amountOfTokensToMint, address sender)
        external
        onlyOwner
        whenNotPaused
        returns (bytes32 requestId)
    {
        // they want to mint $200 and the portfolio has $300 - then that's cool
        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }
        string[] memory args = new string[](1);
        args[0] = "TSLA";
        FunctionsRequest.Request memory req;
        req._initializeRequestForInlineJavaScript(returnType.mint_sourceCode); // Initialize the request with JS code
        req._addDONHostedSecrets(returnType.secretSlot, returnType.secretVersion);
        req._setArgs(args);

        // Send the request and store the request ID
        requestId = _sendRequest(req._encodeCBOR(), returnType.subId, GAS_LIMIT, returnType.donId);
        s_requestIdToRequest[requestId] = dTslaRequest(amountOfTokensToMint, sender);
        return requestId;
    }

    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /* err */ )
        internal
        virtual
        override
        whenNotPaused
    {
        _mintFulFillRequest(requestId, response);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(response)) * getTslaPrice();

        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }

        if (amountOfTokensToMint != 0) {
            _mint(s_requestIdToRequest[requestId].requester, amountOfTokensToMint);
        }
        // Do we need to return anything?
    }

    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    // TSLA USD has 8 decimal places, so we add an additional 10 decimal places
    function getTslaPrice() public returns (uint256) {
        tokenPrice.getCurrentPrice("TSLA");
        uint256 price = tokenPrice.current_price();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(returnType.usdcFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueOfTsla(uint256 tslaAmount) public returns (uint256) {
        return (tslaAmount * getTslaPrice()) / PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/

    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * PRECISION) / getUsdcPrice();
    }

    function getTotalUsdValue() public returns (uint256) {
        return (totalSupply() * getTslaPrice()) / PRECISION;
    }

    function getCalculatedNewTotalValue(uint256 addedNumberOfTsla) public returns (uint256) {
        return ((totalSupply() + addedNumberOfTsla) * getTslaPrice()) / PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (dTslaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    function getWithdrawalAmount(address user) public view returns (uint256) {
        return s_userToWithdrawalAmount[user];
    }
}
