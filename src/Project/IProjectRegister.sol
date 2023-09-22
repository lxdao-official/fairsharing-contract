// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct CreateParams {
    address admin;
    address[] members;
    string tokenName;
    string tokenSymbol;
    address voteStrategy;
    bytes voteStrategyData;
    uint256 votePassingRate;
}

interface IProjectRegister {
    function initialize(
        address _owner,
        address _signer,
        address _projectTemplate,
        address _projectTokenTemplate
    ) external;

    function getSigner() external view returns (address);

    function updateSigner(address _signer) external;

    function getProjectTemplate() external view returns (address);

    function updateProjectTemplate(address _projectTemplate) external;

    function getProjectTokenTemplate() external view returns (address);

    function updateProjectTokenTemplate(address projectTokenTemplate) external;

    function create(CreateParams calldata params) external returns (address);

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
