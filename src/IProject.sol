// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProject {
    function onPassMakeContribution(address attester, bytes calldata data) external returns (bool);

    function onPassRevokeContribution(
        address attester,
        bytes calldata data
    ) external returns (bool);

    function onPassVerifyContribution(
        address attester,
        bytes calldata data
    ) external returns (bool);

    function onPassClaimContribution(address attester, bytes calldata data) external returns (bool);
}
