// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IVotingStrategy.sol";

contract DefaultVotingStrategy is IVotingStrategy {
    constructor() {}

    function getResult(
        address[] calldata,
        uint8[] calldata values,
        bytes calldata,
        uint256 passingRate
    ) external pure returns (bool) {
        // 1:For 2:Against 3:Abstain
        uint256 forResult = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == uint8(1)) {
                forResult = forResult + 1;
            }
        }
        uint256 percentDelta = (forResult * 100) / values.length;
        return percentDelta >= passingRate;
    }
}
