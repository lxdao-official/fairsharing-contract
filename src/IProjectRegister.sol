// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectRegister {
    function getProject(uint256 pid) external returns (address);

    function getSigner() external view returns (address);

    function updateSigner(address _signer) external;

    function updateVoteVerifiers(uint256 pid, bytes32 verifier) external;

    function register(
        uint256 pid,
        address manager,
        bytes32 verifyRoot,
        string memory tokenSymbol
    ) external returns (address);
}
