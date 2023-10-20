// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IVotingStrategy.sol";

struct VotingWeight {
    mapping(address => uint256) weights;
    address member;
    uint256 weight;
}

contract DefaultRelativeVotingStrategy is IVotingStrategy {
    constructor() {}

    function getWeight(
        address[] calldata voters,
        uint256[] calldata weights,
        address voter
    ) internal pure returns (uint256 result) {
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == voter) {
                result = weights[i];
                break;
            }
        }
    }

    function getResult(
        address[] calldata _voters,
        uint8[] calldata values,
        uint256[] calldata weights,
        uint256,
        bytes calldata
    ) external pure returns (bool) {
        address[] calldata voters = _voters;

        // 1:For 2:Against 3:Abstain
        uint256 forResult = 0;
        uint256 againstResult = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == uint8(1)) {
                forResult = forResult + getWeight(voters, weights, voters[i]);
            } else if (values[i] == uint8(2)) {
                againstResult = againstResult + getWeight(voters, weights, voters[i]);
            }
        }
        return forResult > againstResult;
    }
}
