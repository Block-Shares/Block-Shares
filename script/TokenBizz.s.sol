// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.sol";
import {TokenBizz} from "../src/Defi.sol";
import {IGetTslaReturnTypes} from "../src/interfaces/ReturnType.sol";
import {RedeemNvda} from "../src/tokens/RedeemNvda.sol";
import {RedeemTsla} from "../src/tokens/RedeemTsla.sol";
import {RedeemGoog} from "../src/tokens/RedeemGoog.sol";

contract DeployDTsla is Script {
    string constant alpacaMintSource = "Functions/sources/getTokenAmount.js";
    string constant alpacaRedeemSource = "Functions/sources/sellTokenAndSendUsdc.js";
    string constant priceSource = "Functions/sources/tokenPrice.js";
    TokenBizz tokenBizz;
    RedeemNvda redeemNvda;
    RedeemTsla redeemTsla;
    RedeemGoog redeemGoog;

    function run() external {
        // Get params
        IGetTslaReturnTypes.GetTokenBizzReturnType memory tokenReturnType = getdTslaRequirements();
        // Actually deploy

        tokenReturnType.mint_sourceCode = vm.readFile(alpacaMintSource);
        tokenReturnType.redeem_sourceCode = vm.readFile(alpacaRedeemSource);
        tokenReturnType.priceSource = vm.readFile(priceSource);

        vm.startBroadcast();
        tokenBizz = new TokenBizz();
        redeemGoog = new RedeemGoog(tokenReturnType);
        redeemNvda = new RedeemNvda(tokenReturnType);
        redeemTsla = new RedeemTsla(tokenReturnType);
        console.log(address(redeemGoog));
        console.log(address(redeemNvda));
        console.log(address(redeemTsla));
        tokenBizz.setdGoog(address(redeemGoog));
        tokenBizz.setdNvda(address(redeemNvda));
        tokenBizz.setdTsla(address(redeemTsla));
        console.log(address(tokenBizz));
        vm.stopBroadcast();
    }

    function getdTslaRequirements() public returns (IGetTslaReturnTypes.GetTokenBizzReturnType memory typeObject) {
        HelperConfig helperConfig = new HelperConfig();

        typeObject = helperConfig.getactiveNetworkConfig();
        if (
            typeObject.usdcFeed == address(0) || typeObject.functionsRouter == address(0)
                || typeObject.donId == bytes32(0) || typeObject.subId == 0
        ) {
            revert("something is wrong");
        }

        return typeObject;
    }

    // function deployDTSLA(IGetTslaReturnTypes.GetTokenBizzReturnType memory returnObjects) public returns (TokenBizz) {
    //     return dTsla;
    // }
}
