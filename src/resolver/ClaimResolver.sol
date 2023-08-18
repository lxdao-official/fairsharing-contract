// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "../IProjectRegister.sol";
import "../IProject.sol";

contract ClaimResolver is SchemaResolver {
    IProjectRegister private _projectRegister;

    error InvalidCaller();

    constructor(IEAS eas, IProjectRegister projectRegister) SchemaResolver(eas) {
        _projectRegister = projectRegister;
    }

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal override returns (bool) {
        (uint256 pid, , , , , , ) = abi.decode(
            attestation.data,
            (uint256, uint64, bytes32[], address[], uint8[], uint64, bytes)
        );

        address project = IProjectRegister(_projectRegister).getProject(pid);
        require(project != address(0), "Contribution project not found.");
        return IProject(project).onPassClaimContribution(attestation);
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal pure override returns (bool) {
        return true;
    }
}
