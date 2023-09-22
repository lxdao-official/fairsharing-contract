// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./IProjectToken.sol";

contract ProjectToken is OwnableUpgradeable, ERC20Upgradeable, IProjectToken {
    function initialize(
        string memory name,
        string memory symbol,
        address owner
    ) external initializer {
        __ERC20_init(name, symbol);
        _transferOwnership(owner);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }
}
