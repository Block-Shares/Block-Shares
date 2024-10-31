// SPDX-License-Identifier: MIt
pragma solidity 0.8.25;

interface IGetTslaReturnTypes {
    struct GetTokenBizzReturnType {
        uint64 subId;
        address functionsRouter;
        bytes32 donId;
        address usdcFeed;
        uint64 secretVersion;
        uint8 secretSlot;
        string mint_sourceCode;
        string redeem_sourceCode;
        string priceSource;
    }
}
