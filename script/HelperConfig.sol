// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {MockV3Aggregator} from "../src/test/mocks/MockV3Aggregator.sol";
import {MockFunctionsRouter} from "../src/test/mocks/MockFunctionsRouter.sol";
import {MockUSDC} from "../src/test/mocks/MockUSDC.sol";
import {MockLinkToken} from "../src/test/mocks/MockLinkToken.sol";
import {IGetTslaReturnTypes} from "../src/interfaces/ReturnType.sol";

contract HelperConfig {
    mapping(uint256 => IGetTslaReturnTypes.GetTokenBizzReturnType) private chainIdToNetworkConfig;

    IGetTslaReturnTypes.GetTokenBizzReturnType private activeNetworkConfig;

    // Mocks
    MockV3Aggregator public tslaFeedMock;
    MockV3Aggregator public ethUsdFeedMock;
    MockV3Aggregator public usdcFeedMock;
    MockUSDC public usdcMock;
    MockLinkToken public linkTokenMock;

    MockFunctionsRouter public functionsRouterMock;

    string mintSource;
    string redeemSource;

    // TSLA USD, ETH USD, and USDC USD both have 8 decimals
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ANSWER = 2000e8;
    int256 public constant INITIAL_ANSWER_USD = 1e8;

    constructor() {
        // chainIdToNetworkConfig[137] = getPolygonConfig();
        chainIdToNetworkConfig[421614] = getArbitrumConfig();
        chainIdToNetworkConfig[31_337] = _setupAnvilConfig();
        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getArbitrumConfig() internal pure returns (IGetTslaReturnTypes.GetTokenBizzReturnType memory configType) {
        configType = IGetTslaReturnTypes.GetTokenBizzReturnType({
            subId: 214,
            functionsRouter: 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C,
            donId: 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000,
            usdcFeed: 0x0153002d20B96532C639313c2d54c3dA09109309, // to filled in ,
            secretVersion: 1730367776, // to be filled
            secretSlot: 0,
            mint_sourceCode: "", // to be filled in
            redeem_sourceCode: "", // to be filled in"
            priceSource: "" // to be filled in"
        });
    }

    function getAnvilEthConfig() internal pure returns (IGetTslaReturnTypes.GetTokenBizzReturnType memory configType) {
        configType = IGetTslaReturnTypes.GetTokenBizzReturnType({
            subId: 214,
            functionsRouter: 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C,
            donId: 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000,
            // tslaFeed: address(0), // replace with the actual code
            usdcFeed: 0x0153002d20B96532C639313c2d54c3dA09109309, // to filled in ,
            secretVersion: 0, // to be filled
            secretSlot: 0,
            // to be filled in
            mint_sourceCode: "", // to be filled in
            redeem_sourceCode: "", // to be filled in"
            priceSource: "" // to be filled in"
        });
        // minimumRedemptionAmount: 30e6 // Please see your brokerage for min redemption amounts
        // https://alpaca.markets/support/crypto-wallet-faq
    }

    function _setupAnvilConfig() internal returns (IGetTslaReturnTypes.GetTokenBizzReturnType memory configType) {
        usdcMock = new MockUSDC();
        tslaFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        ethUsdFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        usdcFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER_USD);
        functionsRouterMock = new MockFunctionsRouter();
        linkTokenMock = new MockLinkToken();
        return getAnvilEthConfig();
    }

    function getactiveNetworkConfig() public view returns (IGetTslaReturnTypes.GetTokenBizzReturnType memory) {
        return activeNetworkConfig;
    }
}
