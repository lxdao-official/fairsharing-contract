// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectToken {
    function initialize(string memory name, string memory symbol, address owner) external;

    function mint(address account, uint256 amount) external;
}
