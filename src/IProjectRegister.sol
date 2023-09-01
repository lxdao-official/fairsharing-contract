// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectRegister {
    function getSigner() external view returns (address);

    function updateSigner(address _signer) external;

    function create(
        address admin,
        address[] memory members,
        string memory tokenSymbol
    ) external returns (address);

    function totalProject() external view returns (uint256);

    function ownerLatestProject(
        address owner,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (address);
}
