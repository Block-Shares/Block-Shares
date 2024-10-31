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

/**
 * @title TokenBizz
 * @notice This is our contract to make requests to the Alpaca API to mint TSLA-backed dTSLA tokens
 * @dev This contract is meant to be for educational purposes only
 */
contract MintGoog is FunctionsClient, ConfirmedOwner, ERC20, Pausable {
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

    TokenPrice tokenPrice = new TokenPrice(s_functionsRouter, s_donID, i_subId, s_priceSource);

    uint32 private constant GAS_LIMIT = 300_000;
    uint64 immutable i_subId;

    // Check to get the router address for your supported network
    // https://docs.chain.link/chainlink-functions/supported-networks
    address s_functionsRouter;
    string s_mintSource;
    string s_priceSource;

    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 s_donID;
    uint256 s_portfolioBalance;
    uint64 s_secretVersion;
    uint8 s_secretSlot;

    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
    mapping(address user => uint256 amountAvailableForWithdrawal) private s_userToWithdrawalAmount;

    address public immutable i_tslaUsdFeed;
    address public immutable i_usdcUsdFeed;
    // address constant USDC_CONTRACT = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    // This hard-coded value isn't great engineering. Please check with your brokerage
    // and update accordingly
    // For example, for Alpaca: https://alpaca.markets/support/crypto-wallet-faq
    uint256 public constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 100e18;

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
    constructor(
        uint64 subId,
        string memory mintSource,
        address functionsRouter,
        bytes32 donId,
        address usdcPriceFeed,
        uint64 secretVersion,
        uint8 secretSlot
    ) FunctionsClient(functionsRouter) ConfirmedOwner(msg.sender) ERC20("Backed GOOG", "bGOOG") {
        s_mintSource = mintSource;
        s_functionsRouter = functionsRouter;
        s_donID = donId;
        i_usdcUsdFeed = usdcPriceFeed;
        i_subId = subId;

        s_secretVersion = secretVersion;
        s_secretSlot = secretSlot;
    }

    function setSecretVersion(uint64 secretVersion) external onlyOwner {
        s_secretVersion = secretVersion;
    }

    function setSecretSlot(uint8 secretSlot) external onlyOwner {
        s_secretSlot = secretSlot;
    }

    /**
     * @notice Sends an HTTP request for character information
     * @dev If you pass 0, that will act just as a way to get an updated portfolio balance
     * @return requestId The ID of the request
     */
    function sendMintTSLARequest(uint256 amountOfTokensToMint)
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
        args[0] = "GOOGL";
        FunctionsRequest.Request memory req;
        req._initializeRequestForInlineJavaScript(s_mintSource); // Initialize the request with JS code
        req._addDONHostedSecrets(s_secretSlot, s_secretVersion);
        req._setArgs(args);

        // Send the request and store the request ID
        requestId = _sendRequest(req._encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dTslaRequest(amountOfTokensToMint, msg.sender);
        return requestId;
    }

    /*
     * @notice user sends a Chainlink Functions request to sell TSLA for redemptionCoin
     * @notice this will put the redemptionCoin in a withdrawl queue that the user must call to redeem
     *
     * @dev Burn dTSLA
     * @dev Sell TSLA on brokerage
     * @dev Buy USDC on brokerage
     * @dev Send USDC to this contract for user to withdraw
     *
     * @param amountdTsla - the amount of dTSLA to redeem
     */

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     */
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
        s_portfolioBalance = uint256(bytes32(response)) * getGoogPrice();

        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }

        if (amountOfTokensToMint != 0) {
            _mint(s_requestIdToRequest[requestId].requester, amountOfTokensToMint);
        }
        // Do we need to return anything?
    }

    /*
     * @notice the callback for the redeem request
     * At this point, USDC should be in this contract, and we need to update the user
     * That they can now withdraw their USDC
     *
     * @param requestId - the requestId that was fulfilled
     * @param response - the response from the request, it'll be the amount of USDC that was sent
     */

    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    // TSLA USD has 8 decimal places, so we add an additional 10 decimal places
    function getGoogPrice() public returns (uint256) {
        tokenPrice.getCurrentPrice("GOOG");
        uint256 price = tokenPrice.current_price();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_usdcUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueOfGoog(uint256 tslaAmount) public returns (uint256) {
        return (tslaAmount * getGoogPrice()) / PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    /*
     * Pass the USD amount with 18 decimals (WAD)
     * Return the redemptionCoin amount with 18 decimals (WAD)
     *
     * @param usdAmount - the amount of USD to convert to USDC in WAD
     * @return the amount of redemptionCoin with 18 decimals (WAD)
     */
    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * PRECISION) / getUsdcPrice();
    }

    function getTotalUsdValue() public returns (uint256) {
        return (totalSupply() * getGoogPrice()) / PRECISION;
    }

    function getCalculatedNewTotalValue(uint256 addedNumberOfGoog) public returns (uint256) {
        return ((totalSupply() + addedNumberOfGoog) * getGoogPrice()) / PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (dTslaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    function getWithdrawalAmount(address user) public view returns (uint256) {
        return s_userToWithdrawalAmount[user];
    }
}
