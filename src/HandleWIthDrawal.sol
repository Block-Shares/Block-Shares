// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WithDrawalHandler is Pausable {
    mapping(address user => uint256 amountAvailableForWithdrawal) s_userToWithdrawalAmount;
    address private constant USDC_CONTRACT = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    constructor() {}

    error dTSLA__RedemptionFailed();

    function withdraw() external whenNotPaused {
        uint256 amountToWithdraw = s_userToWithdrawalAmount[msg.sender];
        s_userToWithdrawalAmount[msg.sender] = 0;
        // Send the user their USDC
        bool succ = ERC20(USDC_CONTRACT).transfer(msg.sender, amountToWithdraw);
        if (!succ) {
            revert dTSLA__RedemptionFailed();
        }
    }
}
