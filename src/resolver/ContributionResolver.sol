// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IProjectRegister.sol";
import "../IProject.sol";

contract ContributionResolver is Ownable, SchemaResolver {
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
            (uint256, uint64, string, string, string, uint64, bytes32[])
        );

        address project = IProjectRegister(_projectRegister).getProject(pid);
        require(project != address(0), "Contribution project not found.");
        return IProject(project).onPassMakeContribution(attestation.attester, attestation.data);
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal pure override returns (bool) {
        return true;
    }
}
