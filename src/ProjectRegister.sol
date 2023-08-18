// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./IProjectRegister.sol";
import "./IProject.sol";

contract ProjectRegistry is Ownable, IProjectRegister {
    mapping(uint256 => address) public projects;
    mapping(uint256 => bytes32) public voteVerifiers;

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

    function updateVoteVerifiers(uint256 pid, bytes32 verifier) external {
        IProject(projects[pid]).updateMerkleRoot(verifier);
    }

    function register(
        uint256 pid,
        address manager,
        bytes32 verifyRoot
    ) external returns (address projectAddress) {
        //        bytes memory initCode = abi.encodePacked(type(Seaport).creationCode, abi.encode(pid));
        //        address _project = Create2.computeAddress(bytes32(salt), keccak256(initCode));
        //        if (_project == address(0)) revert AccountCreationFailed();
        //        if (initData.length != 0) {
        //            (bool success, bytes memory result) = _project.call(initData);
        //
        //            if (!success) {
        //                assembly {
        //                    revert(add(result, 32), mload(result))
        //                }
        //            }
        //        }

        bytes32 salt = keccak256(abi.encodePacked(pid));
        Project _project = new Project{salt: salt}(address(this), pid, manager, verifyRoot);
        _project.initialize();

        projectAddress = address(_project);

        projects[pid] = projectAddress;
    }

    function getProject(uint256 pid) external view returns (address) {
        return projects[pid];
    }
}

contract Project is AccessControl, IProject {
    address public register;
    uint256 public pid;
    bytes32 public merkleRoot;

    constructor(address _register, uint256 _pid, address _manager, bytes32 _merkleRoot) {
        register = _register;
        pid = _pid;
        merkleRoot = _merkleRoot;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _manager);
    }

    function initialize() public {}

    function updateMerkleRoot(bytes32 _merkleRoot) public {
        merkleRoot = _merkleRoot;
    }

    function onPassMakeContribution(
        address attester,
        bytes calldata data
    ) external view returns (bool) {
        console2.log("Project onPassMakeContribution:");

        (uint256 _pid, , bytes32[] memory proof, , , , ) = abi.decode(
            data,
            (uint256, uint64, bytes32[], string, string, string, uint64)
        );

        require(_pid == pid, "Make contribution verify pid failed.");

        require(
            MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(attester))),
            "Make contribution verify proof failed."
        );

        return true;
    }

    function onPassRevokeContribution(address, bytes calldata) external pure returns (bool) {
        console2.log("Project onPassRevokeContribution:");

        return true;
    }

    function onPassVerifyContribution(
        address attester,
        bytes calldata data
    ) external view returns (bool) {
        console2.log("Project onPassVerifyContribution:");

        (uint256 _pid, , bytes32[] memory proof, , ) = abi.decode(
            data,
            (uint256, uint64, bytes32[], uint8, string)
        );

        require(_pid == pid, "Make contribution verify pid failed.");

        require(
            MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(attester))),
            "Make vote verify proof failed."
        );

        return true;
    }

    function onPassClaimContribution(
        Attestation calldata attestation
    ) external view returns (bool) {
        console2.log("Project onPassClaimContribution:");

        (
            uint256 _pid,
            uint64 cid,
            bytes32[] memory proof,
            address[] memory voters,
            uint8[] memory values,
            uint64 token,
            bytes memory signature
        ) = abi.decode(
                attestation.data,
                (uint256, uint64, bytes32[], address[], uint8[], uint64, bytes)
            );

        // verify pid
        require(_pid == pid, "Make contribution verify pid failed.");

        // verify proof
        require(
            MerkleProof.verify(
                proof,
                merkleRoot,
                keccak256(abi.encodePacked(attestation.attester))
            ),
            "Make claim verify proof failed."
        );

        // verify signature
        bytes32 hash = keccak256(abi.encode(attestation.attester, pid, cid, attestation.refUID));
        require(
            ECDSA.recover(hash, signature) == IProjectRegister(register).getSigner(),
            "Make claim verify signature failed"
        );

        // verify votes

        return true;
    }
}
