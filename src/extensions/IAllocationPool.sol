// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct Allocation {
    address token;
    uint256 unClaimedAmount;
    address[] addresses;
    uint256[] tokenAmounts;
    uint32[] ratios;
}

struct ExtraParams {
    address projectAddress;
    address depositor;
    uint256 timeToClaim;
    uint256 salt;
}

struct CreatPoolExtraParams {
    address owner;
    address projectAddress;
    address creator;
    address depositor;
    uint256 timeToClaim;
}

interface IAllocationPoolFactory {
    function updateTemplate(address _allocationPoolTemplate) external;

    function create(
        Allocation[] calldata allocations,
        ExtraParams calldata param
    ) external returns (address);

    function predictPoolAddress(address creator, uint256 salt) external view returns (address);
}

interface IAllocationPoolTemplate {
    function initialize(
        Allocation[] calldata allocations,
        CreatPoolExtraParams calldata params
    ) external;

    function deposit(address[] calldata tokens, uint256[] calldata amounts) external payable;

    function refund() external;

    function refundUnspecifiedToken(address token) external;

    function claim() external;
}
