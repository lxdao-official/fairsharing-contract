// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@eas/contracts/resolver/SchemaResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IProjectRegister.sol";
import "../IProject.sol";

contract ContributionResolver is Ownable, SchemaResolver {
    address public attester;
    address private _projectRegister;

    error InvalidCaller();

    constructor(IEAS eas, address projectRegister) SchemaResolver(eas) Ownable(_msgSender()) {
        attester = msg.sender;
        _projectRegister = projectRegister;
    }

    /// @notice Updates the attester for future
    /// @param _attester The new attester address to be set in the contract state.
    function updateAttester(address _attester) external onlyOwner {
        attester = _attester;
    }

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal override returns (bool) {
        if (attestation.attester != attester) revert InvalidCaller();
        (uint256 projectId, string memory title, string memory detail, string memory poc, ) = abi
            .decode(attestation.data, (uint256, string, string, string, string));

        address project = IProjectRegister(_projectRegister).getProject(projectId);
        return IProject(project).onPassMakeContribution();
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal override returns (bool) {
        return true;
    }
}
