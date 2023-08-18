// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

interface IProject {
    function getToken() external returns (address);

    function updateMerkleRoot(bytes32 _merkleRoot) external;

    function onPassMakeContribution(address attester, bytes calldata data) external returns (bool);

    function onPassRevokeContribution(
        address attester,
        bytes calldata data
    ) external returns (bool);

    function onPassVerifyContribution(
        address attester,
        bytes calldata data
    ) external returns (bool);

    function onPassClaimContribution(Attestation calldata attestation) external returns (bool);
}
