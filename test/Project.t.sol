// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ProjectRegistry} from "../src/ProjectRegister.sol";

contract CounterTest is Test {
    ProjectRegistry public registry;

    function setUp() public {
        (address addr, ) = makeAddrAndKey("1337");
        registry = new ProjectRegistry(addr);
    }

    function testUpdateSigner() public {
        (address addr, ) = makeAddrAndKey("1338");
        registry.updateSigner(addr);
        assertEq(registry.signer(), addr);
    }
}
