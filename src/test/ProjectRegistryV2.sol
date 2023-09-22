// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../project/IProjectRegister.sol";
import "../project/IProject.sol";
import "../project/ProjectToken.sol";
import "../project/IProjectRegister.sol";

contract ProjectRegistryV2 is OwnableUpgradeable, IProjectRegister {
    // projects indexer
    mapping(uint256 => address) public projectsIndexer;

    // The number of projects created, used to give an incremental id to each one
    uint256 public projectsCount;

    // The signer for project claim.
    address private signer;

    // The project template for clone
    address private projectTemplate;

    // The token template for clone
    address private projectTokenTemplate;

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

    /**
     * @dev Constructors are replaced by initialize function
     */
    function initialize(
        address _owner,
        address _signer,
        address _projectTemplate,
        address _projectTokenTemplate
    ) external initializer {
        // owner
        require(_owner != address(0), "The owner cannot be initialized zero.");
        _transferOwnership(_owner);

        // signer
        signer = _signer;

        // project template
        projectTemplate = _projectTemplate;

        // project token template
        projectTokenTemplate = _projectTokenTemplate;
    }

    /**
     * @dev Get signer
     */
    function getSigner() public view returns (address) {
        return signer;
    }

    /**
     * @dev Update signer, only owner.
     */
    function updateSigner(address _signer) external onlyOwner {
        if (_signer != address(0) && _signer != signer) {
            emit SignerChanged(_msgSender(), signer, _signer);
            signer = _signer;
        }
    }

    /**
     * @dev Get project template
     */
    function getProjectTemplate() external view returns (address) {
        return projectTemplate;
    }

    /**
     * @dev Update project template, only owner.
     */
    function updateProjectTemplate(address _projectTemplate) external onlyOwner {
        if (_projectTemplate != address(0) && _projectTemplate != projectTemplate) {
            emit ProjectTemplateChanged(_msgSender(), projectTemplate, _projectTemplate);
            projectTemplate = _projectTemplate;
        }
    }

    /**
     * @dev Get project token template
     */
    function getProjectTokenTemplate() external view returns (address) {
        return projectTokenTemplate;
    }

    /**
     * @dev Update project token template, only owner.
     */
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

    /**
     * @dev Create project by anyone
     *
     * Voting strategy default is DefaultVotingStrategy
     *
     */
    function create(CreateParams calldata params) external returns (address projectAddress) {
        uint256 index = projectsCount;
        address token = ClonesUpgradeable.cloneDeterministic(
            projectTokenTemplate,
            keccak256(abi.encodePacked(index, params.tokenSymbol))
        );

        projectAddress = ClonesUpgradeable.cloneDeterministic(
            projectTemplate,
            keccak256(abi.encodePacked(index))
        );

        InitializeParams memory initParams = InitializeParams({
            register: address(this),
            owner: params.admin,
            members: params.members,
            votingStrategy: VotingStrategy({
                addr: params.voteStrategy,
                data: params.voteStrategyData,
                passingRate: params.votePassingRate
            }),
            token: token
        });

        // project initialize
        IProject(projectAddress).initialize(initParams);

        // token initialize
        IProjectToken(token).initialize(params.tokenName, params.tokenSymbol, projectAddress);

        emit ProjectCreated(projectAddress, projectTemplate, index);

        projectsIndexer[index] = projectAddress;
        projectsCount++;
    }

    /**
     * @dev Use to get the owner's latest project in off-chain
     */
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

    /**
     * @dev Version of the ProjectRegistry contract. Default: "1.0.0"
     */
    function version() public pure virtual returns (string memory) {
        return "1.0.1";
    }
}
