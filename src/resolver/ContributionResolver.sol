// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IProjectRegister.sol";
import "../IProject.sol";

contract ContributionResolver is Ownable, SchemaResolver {
    //    address public attester;
    IProjectRegister private _projectRegister;

    error InvalidCaller();

    constructor(IEAS eas, IProjectRegister projectRegister) SchemaResolver(eas) {
        //        attester = msg.sender;
        _projectRegister = projectRegister;
    }

    //    /// @notice Updates the attester for future
    //    /// @param _attester The new attester address to be set in the contract state.
    //    function updateAttester(address _attester) external onlyOwner {
    //        attester = _attester;
    //    }

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal override returns (bool) {
        console2.log("ContributionResolver onAttest:");
        console2.logBytes32(attestation.uid);
        //        if (attestation.attester != attester) revert InvalidCaller();
        (uint256 projectId, , , , , ) = abi.decode(
            attestation.data,
            (uint256, uint64, string, string, string, uint64)
        );

        address project = IProjectRegister(_projectRegister).getProject(projectId);
        return IProject(project).onPassMakeContribution(_msgSender(), attestation.data);
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal override returns (bool) {
        return true;
    }
}
