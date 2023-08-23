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
    mapping(uint256 => address) public projects;
    //    mapping(uint256 => bytes32) public voteVerifiers;

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

    //    function updateVoteVerifiers(uint256 pid, bytes32 verifier) external {
    //        IProject(projects[pid]).updateMerkleRoot(verifier);
    //    }

    function register(
        uint256 pid,
        address owner,
        address[] memory members,
        string memory tokenSymbol
    ) external returns (address projectAddress) {
        require(projects[pid] == address(0), "duplicated pid");

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
    address public register;
    uint256 public pid;
    //    bytes32 public merkleRoot;
    mapping(address => bool) members;

    IProjectToken public token;

    constructor(
        address _register,
        uint256 _pid,
        address _owner,
        address[] memory _members,
        string memory tokenSymbol
    ) {
        register = _register;
        pid = _pid;
        //        merkleRoot = _merkleRoot;

        address[] memory empty = new address[](0);
        _setMembers(_members, empty);

        initialize(_owner, tokenSymbol);
    }

    function initialize(address _owner, string memory tokenSymbol) private {
        _transferOwnership(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        token = new ProjectToken(tokenSymbol, tokenSymbol);
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    //    function updateMerkleRoot(bytes32 _merkleRoot) public onlyRole(DEFAULT_ADMIN_ROLE) {
    //        merkleRoot = _merkleRoot;
    //    }

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

    function countVotesResult(
        address[] memory,
        uint8[] memory values
    ) internal pure returns (bool) {
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

    function onPassRevokeContribution(address, bytes calldata) external pure returns (bool) {
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

        // verify pid
        require(_pid == pid, "Make contribution verify pid failed.");

        require(members[attester] == true, "Make vote verify failed.");

        // verify signature
        bytes32 hash = keccak256(abi.encode(attester, pid, cid, attestation.refUID));
        require(
            ECDSA.recover(hash, signature) == IProjectRegister(register).getSigner(),
            "Make claim verify signature failed"
        );

        // count votes
        bool result = countVotesResult(voters, values);
        if (result) {
            // mint
            IProjectToken(token).mint(attester, amount);
            return true;
        } else {
            return false;
        }
    }
}
