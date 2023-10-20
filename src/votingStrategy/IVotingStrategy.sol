// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct VotingStrategy {
    address addr;
    uint256[] weights;
    uint256 threshold;
    bytes data;
}

interface IVotingStrategy {
    function getResult(
        address[] calldata voters,
        uint8[] calldata values,
        uint256[] memory weights,
        uint256 threshold,
        bytes calldata data
    ) external returns (bool);
}
