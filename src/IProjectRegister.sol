// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectRegister {
    function register(uint256 pid, address manager, bytes32 verifyRoot) external returns (address);

    function getProject(uint256 pid) external returns (address);

    function getSigner() external view returns (address);

    function updateSigner(address _signer) external;

    function updateVoteVerifiers(uint256 pid, bytes32 verifier) external;
}
