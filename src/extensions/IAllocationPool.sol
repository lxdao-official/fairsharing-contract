// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct Allocation {
    address token;
    address[] addresses;
    uint256[] amounts;
}

struct AllocationPoolInitializeParams {
    address projectAddress;
    address creator;
    address depositor;
    uint256 timeToClaim;
    //    Allocation[] allocations;
    //    address[] tokens;
    //    mapping(address => address[]) tokenAddresses;
    //    mapping(address => address[]) tokenAmounts;
}

interface IAllocationPoolFactory {
    function create(
        AllocationPoolInitializeParams calldata param,
        Allocation[] calldata allocations
    ) external returns (address);
}

interface IAllocationPoolTemplate {
    function initialize(
        AllocationPoolInitializeParams calldata param,
        Allocation[] calldata allocations
    ) external;
}
