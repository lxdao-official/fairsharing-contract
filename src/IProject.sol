// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IProject {
    function onPassMakeContribution() external returns (bool);

    function onPassRevokeContribution() external returns (bool);

    function onPassVerifyContribution() external returns (bool);

    function onPassClaimContribution() external returns (bool);
}
