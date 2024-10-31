// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/dev/v1_X/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/dev/v1_X/libraries/FunctionsRequest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AggregatorV3Interface, OracleLib} from "src/libaries/OracleLib.sol";
import {TokenPrice} from "../PriceFeed.sol";
import {MintNvda} from "src/tokens/MintNvda.sol";
import {WithDrawalHandler} from "../HandleWIthDrawal.sol";

contract RedeemNvda is FunctionsClient, ConfirmedOwner, Pausable, MintNvda, WithDrawalHandler {
    using FunctionsRequest for FunctionsRequest.Request;
    using OracleLib for AggregatorV3Interface;
    using Strings for uint256;

    address token_address;

    uint32 private constant GAS_LIMIT = 300_000;

    string s_redeemSource;

    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;

    uint256 private constant PRECISION = 1e18;
    uint256 constant USDC_DECIMAL = 6;

    constructor(
        uint64 subId,
        string memory redeemSource,
        string memory priceSource,
        string memory mintSource,
        address functionsRouter,
        bytes32 donId,
        address usdcPriceFeed,
        uint64 secretVersion,
        uint8 secretSlot
    )
        WithDrawalHandler()
        MintNvda(i_subId, mintSource, functionsRouter, donId, usdcPriceFeed, secretVersion, secretSlot)
    {
        s_redeemSource = redeemSource;
        s_priceSource = priceSource;
        s_mintSource = mintSource;
        s_functionsRouter = functionsRouter;
        s_donID = donId;
        i_usdcUsdFeed = usdcPriceFeed;
        i_subId = subId;

        s_secretVersion = secretVersion;
        s_secretSlot = secretSlot;
    }

    function sendRedeemRequest(uint256 amountdNvda) external whenNotPaused returns (bytes32 requestId) {
        if (balanceOf(msg.sender) < (amountdNvda * 1e18)) {
            revert("insufficient asset balance");
        }

        uint256 amountNvdaInUsdc = getUsdcValueOfUsd(getUsdValueOfNvda(amountdNvda));
        if (amountNvdaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert dTSLA__BelowMinimumRedemption();
        }

        // Internal Effects
        FunctionsRequest.Request memory req;
        req._initializeRequestForInlineJavaScript(s_redeemSource); // Initialize the request with JS code
        string[] memory args = new string[](3);
        args[0] = amountdNvda.toString();
        // The transaction will fail if it's outside of 2% slippage
        // This could be a future improvement to make the slippage a parameter by someone
        args[1] = amountNvdaInUsdc.toString();
        args[2] = "NVDA";

        // Send the request and store the request ID
        // We are assuming requestId is unique
        requestId = _sendRequest(req._encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dTslaRequest(amountdNvda, msg.sender);

        // External Interactions
        _burn(msg.sender, amountdNvda);
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     */
    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /* err */ )
        internal
        override(FunctionsClient, MintNvda)
        whenNotPaused
    {
        _redeemFulFillRequest(requestId, response);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice the callback for the redeem request
     * At this point, USDC should be in this contract, and we need to update the user
     * That they can now withdraw their USDC
     *
     * @param requestId - the requestId that was fulfilled
     * @param response - the response from the request, it'll be the amount of USDC that was sent
     */
    function _redeemFulFillRequest(bytes32 requestId, bytes memory response) internal {
        // This is going to have redemptioncoindecimals decimals
        uint256 usdcAmount = uint256(bytes32(response));
        uint256 usdcAmountWad;
        if (USDC_DECIMAL < 18) {
            usdcAmountWad = usdcAmount * (10 ** (18 - USDC_DECIMAL));
        }
        if (usdcAmount == 0) {
            uint256 amountOfdTSLABurned = s_requestIdToRequest[requestId].amountOfToken;
            _mint(s_requestIdToRequest[requestId].requester, amountOfdTSLABurned);
            return;
        }

        s_userToWithdrawalAmount[s_requestIdToRequest[requestId].requester] += usdcAmount;
    }
}
