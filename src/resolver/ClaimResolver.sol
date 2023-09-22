// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../project/IProject.sol";

contract ClaimResolver is Ownable, SchemaResolver {
    constructor(IEAS eas) SchemaResolver(eas) {}

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal override returns (bool) {
        (address projectAddress, , , , , , ) = abi.decode(
            attestation.data,
            (address, uint64, address[], uint8[], address, uint256, bytes)
        );

        require(projectAddress != address(0), "Contribution project not found.");
        return IProject(projectAddress).onPassClaimContribution(attestation);
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal pure override returns (bool) {
        return true;
    }
}
