// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "../votingStrategy/IVotingStrategy.sol";

struct InitializeParams {
    address creator;
    address register;
    address[] admins;
    address[] members;
    VotingStrategy votingStrategy;
    address token;
}

interface IProject {
    function initialize(InitializeParams calldata param) external;

    function setMembers(
        address[] memory addAdminList,
        address[] memory removeAdminList,
        address[] memory addMemberList,
        address[] memory removeMemberList
    ) external;

    function isMember(address from) external view returns (bool);

    function isAdmin(address from) external view returns (bool);

    function updateVotingStrategy(address _votingStrategy) external;

    function updateVotingStrategyData(bytes calldata data) external;

    function getClaims(uint64 cid) external view returns (address);

    function getOwner() external view returns (address);

    function getToken() external returns (address);

    function onPassMakeContribution(Attestation calldata attestation) external returns (bool);

    function onPassRevokeContribution(Attestation calldata attestation) external returns (bool);

    function onPassVoteContribution(Attestation calldata attestation) external returns (bool);

    function onPassClaimContribution(Attestation calldata attestation) external returns (bool);
}
