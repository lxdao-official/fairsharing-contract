// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

interface IProject {
    function initialize(
        address register,
        address owner,
        address[] calldata members,
        address votingStrategy,
        address token
    ) external;

    function getClaims(uint64 cid) external view returns (address);

    function getOwner() external view returns (address);

    function getToken() external returns (address);

    function onPassMakeContribution(Attestation calldata attestation) external returns (bool);

    function onPassRevokeContribution(Attestation calldata attestation) external returns (bool);

    function onPassVoteContribution(Attestation calldata attestation) external returns (bool);

    function onPassClaimContribution(Attestation calldata attestation) external returns (bool);
}
