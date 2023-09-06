// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVotingStrategy {
    function getResult(
        address[] calldata addresses,
        uint8[] calldata values
    ) external returns (bool);
}
