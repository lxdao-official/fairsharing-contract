// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./IProjectRegister.sol";
import "./IProject.sol";
import "./ProjectToken.sol";

contract ProjectRegistry is Ownable, IProjectRegister {
    // Created projects
    mapping(uint256 => address) public projects;

    // The number of projects created, used to give an incremental id to each one
    uint256 public projectsCount;

    // The signer for project claim.
    address public signer;

    constructor(address _signer) {
        signer = _signer;
    }

    function getSigner() public view returns (address) {
        return signer;
    }

    function updateSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function create(
        address owner,
        address[] memory members,
        string memory tokenSymbol
    ) external returns (address projectAddress, uint256 pid) {
        projectsCount++;
        pid = projectsCount;

        bytes32 salt = keccak256(abi.encodePacked(pid));
        Project _project = new Project{salt: salt}(address(this), pid, owner, members, tokenSymbol);

        projectAddress = address(_project);
        projects[pid] = projectAddress;
    }

    function getProject(uint256 pid) external view returns (address) {
        return projects[pid];
    }
}

contract Project is Ownable, AccessControl, IProject {
    using ECDSA for bytes32;

    address public register;
    uint256 public pid;
    mapping(address => bool) public members;

    IProjectToken public token;

    mapping(uint64 => address) public claims;

    constructor(
        address _register,
        uint256 _pid,
        address _owner,
        address[] memory _members,
        string memory tokenSymbol
    ) {
        register = _register;
        pid = _pid;

        address[] memory empty = new address[](0);
        _setMembers(_members, empty);

        initialize(_owner, tokenSymbol);
    }

    function initialize(address _owner, string memory tokenSymbol) private {
        _transferOwnership(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        token = new ProjectToken("FSToken", tokenSymbol);
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

    function onPassMakeContribution(
        address attester,
        bytes calldata data
    ) external view returns (bool) {
        (uint256 _pid, , , , , ) = abi.decode(
            data,
            (uint256, uint64, string, string, string, uint64)
        );

        require(_pid == pid, "Make contribution verify pid failed.");

        require(members[attester] == true, "Make vote verify failed.");

        return true;
    }

    function onPassRevokeContribution(
        address attester,
        bytes calldata data
    ) external view returns (bool) {
        (uint256 _pid, , , , , ) = abi.decode(
            data,
            (uint256, uint64, string, string, string, uint64)
        );

        require(_pid == pid, "Make contribution verify pid failed.");

        require(members[attester] == true, "Revoke vote verify failed.");

        return true;
    }

    function onPassVerifyContribution(
        address attester,
        bytes calldata data
    ) external view returns (bool) {
        (uint256 _pid, , , ) = abi.decode(data, (uint256, uint64, uint8, string));

        require(_pid == pid, "Make contribution verify pid failed.");

        require(members[attester] == true, "Make vote verify failed.");

        return true;
    }

    function onPassClaimContribution(Attestation calldata attestation) external returns (bool) {
        address attester = attestation.attester;
        (
            uint256 _pid,
            uint64 cid,
            address[] memory voters,
            uint8[] memory values,
            uint64 amount,
            bytes memory signature
        ) = abi.decode(attestation.data, (uint256, uint64, address[], uint8[], uint64, bytes));

        require(claims[cid] == address(0), "This contribution was claimed");

        // verify pid
        require(_pid == pid, "Make contribution verify pid failed.");

        // verify member
        require(members[attester] == true, "Make vote verify failed.");

        // verify signature
        bytes32 hash = keccak256(abi.encode(attester, pid, cid));
        require(
            hash.toEthSignedMessageHash().recover(signature) ==
                IProjectRegister(register).getSigner(),
            "Make claim verify signature failed"
        );

        // count votes
        bool result = countVotesResult(voters, values);
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
