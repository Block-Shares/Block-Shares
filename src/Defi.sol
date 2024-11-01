// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {WithDrawalHandler} from "./HandleWIthDrawal.sol";

/**
 * @title TokenBizz
 * @notice Manages minting and redeeming of dTSLA, dNVDA, and dGOOG tokens based on Alpaca API data
 */
contract TokenBizz is WithDrawalHandler {
    event Response(bytes32 indexed requestId, uint256 current_balance, bytes response, bytes err);

    address immutable i_owner;

    constructor() WithDrawalHandler() {
        i_owner = msg.sender;
    }

    address private dTsla;
    address private dGoog;
    address private dNvda;

    modifier only_owner() {
        if (msg.sender != i_owner) {
            revert("this permission is restricted");
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                              MINT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mintTsla(uint256 amountOfTokensToMint) public {
        (bool success,) =
            dTsla.call(abi.encodeWithSignature("sendRedeemRequest(uint256, address)", amountOfTokensToMint, msg.sender));
        if (!success) {
            revert("call to mintTsla failed");
        }
    }

    function mintNvda(uint256 amountOfTokensToMint) public {
        (bool success,) =
            dNvda.call(abi.encodeWithSignature("sendRedeemRequest(uint256, address)", amountOfTokensToMint, msg.sender));
        if (!success) {
            revert("call to mintNvda failed");
        }
    }

    function mintGoog(uint256 amountOfTokensToMint) public {
        (bool success,) =
            dGoog.call(abi.encodeWithSignature("sendRedeemRequest(uint256, address)", amountOfTokensToMint, msg.sender));
        if (!success) {
            revert("call to mintGoog failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                              REDEEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function redeemTsla(uint256 amountdTsla) public {
        (bool success,) =
            dTsla.call(abi.encodeWithSignature("sendMintTSLARequest(uint256, address)", amountdTsla, msg.sender));
        if (!success) {
            revert("call to mintTsla failed");
        }
    }

    function redeemNvda(uint256 amountdNvda) public {
        (bool success,) =
            dNvda.call(abi.encodeWithSignature("sendMintTSLARequest(uint256, address)", amountdNvda, msg.sender));
        if (!success) {
            revert("call to mintTsla failed");
        }
    }

    function redeemGoog(uint256 amountdGoog) public {
        (bool success,) =
            dGoog.call(abi.encodeWithSignature("sendMintTSLARequest(uint256, address)", amountdGoog, msg.sender));
        if (!success) {
            revert("call to mintTsla failed");
        }
    }

    function setdTsla(address newAdd) public only_owner {
        dTsla = newAdd;
    }

    function setdGoog(address newAdd) public only_owner {
        dGoog = newAdd;
    }

    function setdNvda(address newAdd) public only_owner {
        dNvda = newAdd;
    }

    /////////////////////////////////////////////////////////
    //          view functions
    /////////////////////////////////////////////////////////

    function getdTsla() public view only_owner returns (address) {
        return dTsla;
    }

    function getdGoog() public view only_owner returns (address) {
        return dGoog;
    }

    function getdNvda() public view returns (address) {
        return dNvda;
    }
}
