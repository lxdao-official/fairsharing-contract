// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./IProjectRegister.sol";
import "./IProject.sol";
import "./ProjectToken.sol";
import "./votingStrategy/IVotingStrategy.sol";

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
        address[] memory members,
        string memory tokenSymbol,
        address voteStrategy
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

        // project initialize
        IProject(projectAddress).initialize(address(this), owner, members, voteStrategy, token);

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

contract Project is Ownable, AccessControl, IProject {
    using ECDSA for bytes32;

    address public register;

    mapping(address => bool) public members;

    IProjectToken public token;

    IVotingStrategy public votingStrategy;

    mapping(uint64 => address) public claims;

    constructor() {}

    function initialize(
        address _register,
        address _owner,
        address[] calldata _members,
        address _votingStrategy,
        address _token
    ) external {
        register = _register;

        votingStrategy = IVotingStrategy(_votingStrategy);

        token = IProjectToken(_token);

        address[] memory empty = new address[](0);
        _setMembers(_members, empty);

        _transferOwnership(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function getClaims(uint64 cid) external view returns (address) {
        return claims[cid];
    }

    function getOwner() external view returns (address) {
        return this.owner();
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function _setMembers(address[] memory addList, address[] memory removeList) internal {
        for (uint256 i = 0; i < addList.length; i++) {
            members[addList[i]] = true;
        }
        for (uint256 i = 0; i < removeList.length; i++) {
            members[removeList[i]] = false;
        }
    }

    function setMembers(
        address[] memory addList,
        address[] memory removeList
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMembers(addList, removeList);
    }

    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    function countVotesResult(address[] memory, uint8[] memory values) private pure returns (bool) {
        // 1:For 2:Against 3:Abstain
        uint256 forResult = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == uint8(1)) {
                forResult = forResult + 1;
            }
        }
        uint256 percentDelta = (forResult * 1e18) / values.length;
        uint256 passPercent = 7 * 1e17;
        return percentDelta >= passPercent;
    }

    function onPassMakeContribution(Attestation calldata attestation) external view returns (bool) {
        require(members[attestation.attester] == true, "Make vote verify failed.");
        return true;
    }

    function onPassRevokeContribution(
        Attestation calldata attestation
    ) external view returns (bool) {
        require(members[attestation.attester] == true, "Revoke vote verify failed.");
        return true;
    }

    function onPassVoteContribution(Attestation calldata attestation) external view returns (bool) {
        require(members[attestation.attester] == true, "Make vote verify failed.");
        return true;
    }

    function onPassClaimContribution(Attestation calldata attestation) external returns (bool) {
        address attester = attestation.attester;
        // verify member
        require(members[attester] == true, "Make vote verify failed.");

        (
            ,
            uint64 cid,
            address[] memory voters,
            uint8[] memory values,
            uint64 amount,
            bytes memory signature
        ) = abi.decode(attestation.data, (address, uint64, address[], uint8[], uint64, bytes));

        require(claims[cid] == address(0), "This contribution was claimed");

        // verify signature
        bytes32 hash = keccak256(abi.encode(block.chainid, attester, cid));
        require(
            hash.toEthSignedMessageHash().recover(signature) ==
                IProjectRegister(register).getSigner(),
            "Make claim verify signature failed"
        );

        // count votes
        bool result = votingStrategy.getResult(voters, values);
        if (result) {
            // mint
            IProjectToken(token).mint(attester, amount);

            // store
            claims[cid] = attester;
            return true;
        } else {
            return false;
        }
    }
}
