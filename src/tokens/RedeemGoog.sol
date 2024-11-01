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
import {MintGoog} from "src/tokens/MintGoog.sol";
import {WithDrawalHandler} from "../HandleWIthDrawal.sol";

contract RedeemGoog is FunctionsClient, ConfirmedOwner, Pausable, MintGoog, WithDrawalHandler {
    using FunctionsRequest for FunctionsRequest.Request;
    using OracleLib for AggregatorV3Interface;
    using Strings for uint256;

    GetTokenBizzReturnType private returnType;

    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;

    uint256 private constant TARGET_DECIMALS = 18;
    uint32 private constant GAS_LIMIT = 300_000;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant USDC_DECIMAL = 6;

    constructor(GetTokenBizzReturnType memory _returnType) MintGoog(_returnType) {
        returnType = _returnType;
    }

    function sendRedeemRequest(uint256 amountGoog, address sender) public whenNotPaused returns (bytes32 requestId) {
        if (balanceOf(sender) < (amountGoog * 1e18)) {
            revert("insufficient asset balance");
        }

        uint256 amountNvdaInUsdc = getUsdcValueOfUsd(getUsdValueOfGoog(amountGoog));
        if (amountNvdaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert dTSLA__BelowMinimumRedemption();
        }

        // Internal Effects
        FunctionsRequest.Request memory req;
        req._initializeRequestForInlineJavaScript(returnType.redeem_sourceCode);
        string[] memory args = new string[](3);
        args[0] = amountGoog.toString();

        args[1] = amountNvdaInUsdc.toString();
        args[2] = "GOOG";

        requestId = _sendRequest(req._encodeCBOR(), returnType.subId, GAS_LIMIT, returnType.donId);
        s_requestIdToRequest[requestId] = dTslaRequest(amountGoog, sender);

        _burn(sender, amountGoog);
    }

    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /* err */ )
        internal
        override(FunctionsClient, MintGoog)
        whenNotPaused
    {
        _redeemFulFillRequest(requestId, response);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

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
