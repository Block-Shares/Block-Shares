// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/dev/v1_X/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/dev/v1_X/FunctionsClient.sol";

/*
 * @title Tokenprice
 * @author Ekene uduike
 * @notice This contract is used to fetch stock price from alpaca.
 */
contract TokenPrice is FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    address s_functionsRouter;
    bytes32 s_donID;
    uint32 constant gasLimit = 300000;
    uint256 constant PRICE_PRECISION = 1e16;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint64 private i_subscriptionId;

    string private s_PriceSource;

    uint256 public current_price;

    constructor(address _functionsRouter, bytes32 donID, uint64 subscriptionId, string memory priceSource)
        FunctionsClient(_functionsRouter)
    {
        s_functionsRouter = _functionsRouter;
        s_donID = donID;
        i_subscriptionId = subscriptionId;
        s_PriceSource = priceSource;
    }

    function getCurrentPrice(string calldata token_symbol) external returns (bytes32 requestId) {
        string[] memory args = new string[](1);
        args[0] = token_symbol;
        FunctionsRequest.Request memory req;
        req._initializeRequestForInlineJavaScript(s_PriceSource); // Initialize the request with JS code
        req._setArgs(args);
        s_lastRequestId = _sendRequest(req._encodeCBOR(), i_subscriptionId, gasLimit, s_donID);
        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        current_price = uint256(bytes32(response)) * PRICE_PRECISION;
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, current_price, s_lastResponse, s_lastError);
    }

    error UnexpectedRequestID(bytes32 requestId);

    // Event to log responses
    event Response(bytes32 indexed requestId, uint256 current_price, bytes response, bytes err);
}
