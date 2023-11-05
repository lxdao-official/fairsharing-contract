// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../project/IProjectRegister.sol";
import "../project/IProject.sol";
import "../project/ProjectToken.sol";
import "../project/IProjectRegister.sol";

contract ProjectRegistryV2 {
    /**
     * @dev Version of the ProjectRegistry contract. Default: "1.0.0"
     */
    function version() public pure virtual returns (string memory) {
        return "1.0.1";
    }
}
