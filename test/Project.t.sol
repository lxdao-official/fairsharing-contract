// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ProjectRegistry} from "../src/ProjectRegister.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@eas/contracts/SchemaRegistry.sol";
import "@eas/contracts/EAS.sol";

contract CounterTest is Test {
    SchemaRegistry private _schemaRegistry;
    EAS private _eas;

    ProjectRegistry private _registry;
    uint256[] projectIds;

    function setUp() public {
        _schemaRegistry = new SchemaRegistry();
        _eas = new EAS(_schemaRegistry);

        (address addr, ) = makeAddrAndKey("1337");
        _registry = new ProjectRegistry(addr);
    }

    function registerProject() public {
        for (uint256 pid = 1; pid < 10; pid++) {
            address addr = makeAddr(Strings.toString(pid));
            _registry.register(pid, addr);
            projectIds.push(pid);
        }
    }

    function testUpdateSigner() public {
        (address addr, ) = makeAddrAndKey("1338");
        _registry.updateSigner(addr);
        assertEq(_registry.signer(), addr);
    }
}
