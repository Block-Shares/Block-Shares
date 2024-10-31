// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenBizz} from "src/Defi.sol";

contract CounterTest is Test {
    TokenBizz tokenbizz;

    function setUp() public {
        // tokenbizz = new TokenBizz();
    }

    function test_Increment() public {}

    function testFuzz_SetNumber(uint256 x) public {}
}
