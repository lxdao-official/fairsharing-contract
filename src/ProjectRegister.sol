// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/StdMath.sol";

import "./IProjectRegister.sol";
import "./IProject.sol";
import "./ProjectToken.sol";

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
        bytes32 verifyRoot,
        string memory tokenSymbol
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
        Project _project = new Project{salt: salt}(
            address(this),
            pid,
            manager,
            verifyRoot,
            tokenSymbol
        );

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

    IProjectToken public token;

    constructor(
        address _register,
        uint256 _pid,
        address _manager,
        bytes32 _merkleRoot,
        string memory tokenSymbol
    ) {
        register = _register;
        pid = _pid;
        merkleRoot = _merkleRoot;

        initialize(_manager, tokenSymbol);
    }

    function initialize(address _manager, string memory tokenSymbol) public {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _manager);

        token = new ProjectToken(tokenSymbol, tokenSymbol);
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function updateMerkleRoot(bytes32 _merkleRoot) public {
        merkleRoot = _merkleRoot;
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
        return true;
    }

    function onPassVerifyContribution(
        address attester,
        bytes calldata data
    ) external view returns (bool) {
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

    function onPassClaimContribution(Attestation calldata attestation) external returns (bool) {
        address attester = attestation.attester;
        (
            uint256 _pid,
            uint64 cid,
            bytes32[] memory proof,
            address[] memory voters,
            uint8[] memory values,
            uint64 amount,
            bytes memory signature
        ) = abi.decode(
                attestation.data,
                (uint256, uint64, bytes32[], address[], uint8[], uint64, bytes)
            );

        // verify pid
        require(_pid == pid, "Make contribution verify pid failed.");

        // verify proof
        require(
            MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(attester))),
            "Make claim verify proof failed."
        );

        // verify signature
        bytes32 hash = keccak256(abi.encode(attester, pid, cid, attestation.refUID));
        require(
            ECDSA.recover(hash, signature) == IProjectRegister(register).getSigner(),
            "Make claim verify signature failed"
        );

        // count votes
        bool result = countVotesResult(voters, values);
        if (result) {
            IProjectToken(token).mint(attester, amount);
            return true;
        } else {
            return false;
        }
    }
}
