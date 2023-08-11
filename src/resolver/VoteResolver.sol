// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@eas/contracts/resolver/SchemaResolver.sol";

contract VoteResolver is SchemaResolver {
    constructor(IEAS eas) SchemaResolver(eas) {}

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    ) internal override returns (bool) {
        return true;
    }

    function onRevoke(
        Attestation calldata /*attestation*/,
        uint256 /*value*/
    ) internal override returns (bool) {
        return true;
    }
}
