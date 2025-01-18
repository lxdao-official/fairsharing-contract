// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IVotingStrategy.sol";

abstract contract VotingStrategyBase is IVotingStrategy {
    constructor() {}

    function getWeight(
        address[] calldata voters,
        uint256[] calldata weights,
        address voter
    ) internal pure returns (uint256) {
        uint256 result = 0;
        if (voters.length == weights.length) {
            for (uint256 i = 0; i < voters.length; i++) {
                if (voters[i] == voter) {
                    result = weights[i];
                    break;
                }
            }
        } else {
            // error params
            result = 1;
        }
        return result;
    }

    function getResult(
        address[] calldata,
        uint8[] calldata,
        uint256[] memory,
        uint256,
        bytes calldata
    ) external virtual returns (bool) {
        return true;
    }
}
