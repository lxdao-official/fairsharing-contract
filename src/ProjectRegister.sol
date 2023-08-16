// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IProjectRegister.sol";
import "./IProject.sol";

contract ProjectRegistry is Ownable, IProjectRegister {
    mapping(uint256 => address) public projects;
    mapping(uint256 => bytes32) public voteVerifiers;

    address public signer;

    constructor(address _signer) {
        signer = _signer;
    }

    function updateSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function updateVoteVerifiers(uint256 pid, bytes32 verifier) external {
        voteVerifiers[pid] = verifier;
    }

    function register(uint256 pid, address manager) external returns (address projectAddress) {
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
        Project _project = new Project{salt: salt}(pid, manager);
        _project.initialize();

        projectAddress = address(_project);

        projects[pid] = projectAddress;
    }

    function getProject(uint256 pid) external view returns (address) {
        return projects[pid];
    }
}

contract Project is AccessControl, IProject {
    uint256 private pid;

    constructor(uint256 _pid, address manager) {
        pid = _pid;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, manager);
    }

    function initialize() public {}

    function onPassMakeContribution(
        address attester,
        bytes calldata data
    ) external pure returns (bool) {
        console2.log("Project onPassMakeContribution:");
        (
            uint256 projectId,
            uint64 cid,
            string memory title,
            string memory detail,
            string memory poc,
            uint64 token
        ) = abi.decode(data, (uint256, uint64, string, string, string, uint64));

        return true;
    }

    function onPassRevokeContribution(address, bytes calldata) external pure returns (bool) {
        return true;
    }

    function onPassVerifyContribution(address, bytes calldata) external pure returns (bool) {
        return true;
    }

    function onPassClaimContribution(address, bytes calldata) external pure returns (bool) {
        return true;
    }
}
