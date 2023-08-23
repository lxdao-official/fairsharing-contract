// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IProjectRegister.sol";
import "../IProject.sol";

contract VoteResolver is Ownable, SchemaResolver {
    IProjectRegister public projectRegister;

    error InvalidCaller();

    constructor(IEAS eas, IProjectRegister _projectRegister) SchemaResolver(eas) {
        projectRegister = _projectRegister;
    }

    function updateProjectRegister(IProjectRegister _projectRegister) external onlyOwner {
        projectRegister = _projectRegister;
    }

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal override returns (bool) {
        (uint256 pid, , , ) = abi.decode(attestation.data, (uint256, uint64, uint8, string));

        address project = IProjectRegister(projectRegister).getProject(pid);
        require(project != address(0), "Contribution project not found.");
        return IProject(project).onPassVerifyContribution(attestation.attester, attestation.data);
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal pure override returns (bool) {
        return true;
    }
}
