// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProjectRegister {
    function getSigner() external view returns (address);

    function updateSigner(address _signer) external;

    function getProjectTemplate() external view returns (address);

    function updateProjectTemplate(address _projectTemplate) external;

    function create(
        address admin,
        address[] memory members,
        string memory tokenSymbol,
        address voteStrategy
    ) external returns (address);

    /**
     * @notice Invoked by off-chain, get owner's latest created project.
     *
     */
    function getOwnerLatestProject(
        address owner,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (address);
}
