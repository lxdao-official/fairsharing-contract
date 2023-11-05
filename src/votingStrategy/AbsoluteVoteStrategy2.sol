// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VotingStrategyBase.sol";

contract AbsoluteVoteStrategy2 is IVotingStrategy, VotingStrategyBase {
    constructor() {}

    function getResult(
        address[] calldata _voters,
        uint8[] calldata values,
        uint256[] calldata weights,
        uint256 threshold,
        bytes calldata
    ) external pure override(IVotingStrategy, VotingStrategyBase) returns (bool) {
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
        uint256 percentDelta = ((forResult - againstResult) * 100) / values.length;
        return percentDelta >= threshold;
    }
}
