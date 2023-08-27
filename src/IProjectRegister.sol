// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectRegister {
    function getProject(uint256 pid) external returns (address);

    function getSigner() external view returns (address);

    function updateSigner(address _signer) external;

    function create(
        address admin,
        address[] memory members,
        string memory tokenSymbol
    ) external returns (address, uint256);
}
