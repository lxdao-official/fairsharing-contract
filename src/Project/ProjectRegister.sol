// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./IProjectRegister.sol";
import "./IProject.sol";
import "./ProjectToken.sol";

contract ProjectRegistry is Ownable, IProjectRegister {
    // projects indexer
    mapping(uint256 => address) public projectsIndexer;

    // The number of projects created, used to give an incremental id to each one
    uint256 public projectsCount;

    // The signer for project claim.
    address public signer;

    // The project template for clone
    address public projectTemplate;

    // The token template for clone
    address public projectTokenTemplate;

    /**
     * @dev Emitted when signer changed.
     */
    event SignerChanged(address indexed operator, address indexed from, address indexed to);

    /**
     * @dev Emitted when project template changed.
     */
    event ProjectTemplateChanged(
        address indexed operator,
        address indexed from,
        address indexed to
    );

    /**
     * @dev Emitted when project token template changed.
     */
    event ProjectTokenTemplateChanged(
        address indexed operator,
        address indexed from,
        address indexed to
    );

    /**
     * @dev Emitted when project template changed.
     */
    event ProjectCreated(
        address indexed projectAddress,
        address indexed implementation,
        uint256 index
    );

    constructor(address _signer, address _projectTemplate, address _projectTokenTemplate) {
        signer = _signer;
        projectTemplate = _projectTemplate;
        projectTokenTemplate = _projectTokenTemplate;
    }

    function getSigner() public view returns (address) {
        return signer;
    }

    function updateSigner(address _signer) external onlyOwner {
        if (_signer != address(0) && _signer != signer) {
            emit SignerChanged(_msgSender(), signer, _signer);
            signer = _signer;
        }
    }

    function getProjectTemplate() external view returns (address) {
        return projectTemplate;
    }

    function updateProjectTemplate(address _projectTemplate) external onlyOwner {
        if (_projectTemplate != address(0) && _projectTemplate != projectTemplate) {
            emit ProjectTemplateChanged(_msgSender(), projectTemplate, _projectTemplate);
            projectTemplate = _projectTemplate;
        }
    }

    function getProjectTokenTemplate() external view returns (address) {
        return projectTokenTemplate;
    }

    function updateProjectTokenTemplate(address _projectTokenTemplate) external onlyOwner {
        if (_projectTokenTemplate != address(0) && _projectTokenTemplate != projectTokenTemplate) {
            emit ProjectTokenTemplateChanged(
                _msgSender(),
                projectTokenTemplate,
                _projectTokenTemplate
            );
            projectTokenTemplate = _projectTokenTemplate;
        }
    }

    function create(
        address owner,
        address[] calldata members,
        string calldata tokenSymbol,
        address voteStrategy,
        bytes calldata voteStrategyData
    ) external returns (address projectAddress) {
        uint256 index = projectsCount;
        address token = ClonesUpgradeable.cloneDeterministic(
            projectTokenTemplate,
            keccak256(abi.encodePacked(index, tokenSymbol))
        );

        projectAddress = ClonesUpgradeable.cloneDeterministic(
            projectTemplate,
            keccak256(abi.encodePacked(index))
        );

        InitializeParams memory params = InitializeParams({
            register: address(this),
            owner: owner,
            members: members,
            votingStrategy: VotingStrategy({addr: voteStrategy, data: voteStrategyData}),
            token: token
        });

        // project initialize
        IProject(projectAddress).initialize(params);

        // token initialize
        IProjectToken(token).initialize("FSToken", tokenSymbol, projectAddress);

        emit ProjectCreated(projectAddress, projectTemplate, index);

        projectsIndexer[index] = projectAddress;
        projectsCount++;
    }

    function getOwnerLatestProject(
        address owner,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (address) {
        address projectAddress;
        if (startIndex >= 0 && startIndex <= endIndex && endIndex < projectsCount) {
            for (uint256 i = endIndex; i >= startIndex; ) {
                if (owner == IProject(projectsIndexer[i]).getOwner()) {
                    projectAddress = projectsIndexer[i];
                    break;
                }
                if (i > 0) {
                    i--;
                } else {
                    break;
                }
            }
        } else {
            revert("startIndex or endIndex out of range.");
        }
        return projectAddress;
    }
}
