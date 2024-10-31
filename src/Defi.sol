// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/dev/v1_X/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/dev/v1_X/libraries/FunctionsRequest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {RedeemGoog} from "../src/tokens/RedeemGoog.sol";
import {RedeemNvda} from "../src/tokens/RedeemNvda.sol";
import {RedeemTsla} from "../src/tokens/RedeemTsla.sol";
import {WithDrawalHandler} from "src/HandleWIthDrawal.sol";
import {IGetTslaReturnTypes} from "../src/interfaces/ReturnType.sol";

/**
 * @title TokenBizz
 * @notice This is our contract to make requests to the Alpaca API to mint TSLA-backed dTSLA tokens
 * @dev This contract is meant to be for educational purposes only
 */
contract TokenBizz is ConfirmedOwner, WithDrawalHandler, IGetTslaReturnTypes {
    // emit DebugLog("Constructor started");

    /*//////////////////////////////////////////////////////////////
                         RWA TOKENS INITIALIZATION 
    ////////////////////////////////////////////////////////////*/

    RedeemGoog private Goog;
    RedeemNvda private Nvda;
    RedeemTsla private Tsla;

    /*//////////////////////////////////////////////////////////////
                              state varables
    //////////////////////////////////////////////////////////////*/

    string s_redeem_sourceCode;
    string s_mint_sourceCode;
    string s_pricecode;

    // Check to get the router address for your supported network
    // https://docs.chain.link/chainlink-functions/supported-networks
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address s_functionsRouter;
    bytes32 s_donID;
    uint64 s_secretVersion;
    uint8 s_secretSlot;

    // mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
    // mapping(address user => uint256 amountAvailableForWithdrawal) private s_userToWithdrawalAmount;

    address private immutable i_usdcUsdFeed;
    uint64 immutable i_subId;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS 
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 100e18;
    uint32 private constant GAS_LIMIT = 300_000;

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PORTFOLIO_PRECISION = 1e18;
    uint256 public constant COLLATERAL_RATIO = 200; // 200% collateral ratio
    uint256 public constant COLLATERAL_PRECISION = 100;

    uint256 private constant TARGET_DECIMALS = 18;
    uint256 private constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS AND Errors
    //////////////////////////////////////////////////////////////*/
    event Response(bytes32 indexed requestId, uint256 character, bytes response, bytes err);

    error UnexpectedRequestID(bytes32 requestId);

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(GetTokenBizzReturnType memory returnType) ConfirmedOwner(msg.sender) WithDrawalHandler() {
        s_mint_sourceCode = returnType.mint_sourceCode;
        s_redeem_sourceCode = returnType.redeem_sourceCode;
        s_pricecode = returnType.priceSource;

        s_functionsRouter = returnType.functionsRouter;
        s_donID = returnType.donId;
        i_usdcUsdFeed = returnType.usdcFeed;
        i_subId = returnType.subId;

        s_secretVersion = returnType.secretVersion;
        s_secretSlot = returnType.secretSlot;


        Tsla = new RedeemTsla(
        i_subId,
        s_redeem_sourceCode,
        s_pricecode,
        s_mint_sourceCode,
        s_functionsRouter,
        s_donID,
        i_usdcUsdFeed,
        s_secretVersion,
        s_secretSlot
    );
     Nvda = new RedeemNvda(
        i_subId,
        s_redeem_sourceCode,
        s_pricecode,
        s_mint_sourceCode,
        s_functionsRouter,
        s_donID,
        i_usdcUsdFeed,
        s_secretVersion,
        s_secretSlot
    );
    Goog = new RedeemGoog(
        i_subId,
        s_redeem_sourceCode,
        s_pricecode,
        s_mint_sourceCode,
        s_functionsRouter,
        s_donID,
        i_usdcUsdFeed,
        s_secretVersion,
        s_secretSlot
    );

    }

    function setSecretVersion(uint64 secretVersion) external onlyOwner {
        s_secretVersion = secretVersion;
    }

    function setSecretSlot(uint8 secretSlot) external onlyOwner {
        s_secretSlot = secretSlot;
    }

    /*//////////////////////////////////////////////////////////////
                            MINTS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // this functions should have a fee switch and also require user
    // to deposit the eqivalent of eth for the amount of stock they wish
    // to buy, but to avoid difficulties getting test token to stimulate this.abi
    // we have removed that and allow users to mint without deposit just for testing

    function MintTsla(uint256 amountOfTokensToMint) external {
        Tsla.sendMintTSLARequest(amountOfTokensToMint);
    }

    function MintNvda(uint256 amountOfTokensToMint) external {
        Nvda.sendMintTSLARequest(amountOfTokensToMint);
    }

    function MintGoog(uint256 amountOfTokensToMint) external {
        Goog.sendMintTSLARequest(amountOfTokensToMint);
    }

    // /*//////////////////////////////////////////////////////////////
    //                         REDEEM FUNCTIONS
    // //////////////////////////////////////////////////////////////*/
    function getRedeemTsla(uint256 amountdTsla) external {
        Tsla.sendRedeemRequest(amountdTsla);
    }

    function getRedeemNvda(uint256 amountdTsla) external {
        Nvda.sendRedeemRequest(amountdTsla);
    }

    function getRedeemGoog(uint256 amountdTsla) external {
        Goog.sendRedeemRequest(amountdTsla);
    }
}
