// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AllocateResolver is Ownable, SchemaResolver {
    constructor(IEAS eas) SchemaResolver(eas) {}

    function isPayable() public pure override returns (bool) {
        return false;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal view override returns (bool) {
        (address projectAddress, , , , ) = abi.decode(
            attestation.data,
            (address, string, address[], uint16[], uint256[])
        );
        require(projectAddress != address(0), "Project not found.");
        return IAccessControl(projectAddress).hasRole(0x00, attestation.attester);
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal pure override returns (bool) {
        return true;
    }
}
