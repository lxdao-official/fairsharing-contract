// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IProjectRegister {
    function register(uint256 pid, address manager) external returns (address);

    function getProject(uint256 pid) external returns (address);
}
