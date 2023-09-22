// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IVotingStrategy.sol";

struct VotingWeight {
    mapping(address => uint256) weights;
    address member;
    uint256 weight;
}

contract VotingWeightStrategy is IVotingStrategy {
    constructor() {}

    function getWeight(
        address[] memory members,
        uint256[] memory weights,
        address member
    ) internal pure returns (uint256 result) {
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == member) {
                result = weights[i];
                break;
            }
        }
    }

    function getResult(
        address[] calldata voters,
        uint8[] calldata values,
        bytes calldata data,
        uint256 passingRate
    ) external pure returns (bool) {
        (address[] memory members, uint256[] memory weights) = abi.decode(
            data,
            (address[], uint256[])
        );

        uint256 total = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            total += weights[i];
        }
        require(total == 100, "Total vate weight is invalid.");

        // 1:For 2:Against 3:Abstain
        uint256 forResult = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == uint8(1)) {
                forResult = forResult + getWeight(members, weights, voters[i]);
            }
        }
        return forResult >= passingRate;
    }
}
