// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ProjectRegistry} from "../src/ProjectRegister.sol";

contract CounterTest is Test {
    ProjectRegistry public registry;

    function setUp() public {
        (address addr, ) = makeAddrAndKey("1337");
        registry = new ProjectRegistry(addr);
        console.logString("signer");
        console2.logString("signer");
    }

    function testUpdateSigner(address _signer) public {
        console2.logString("signer:%@", _signer);
        registry.updateSigner(_signer);
        assertEq(registry.signer(), _signer);
    }
}
