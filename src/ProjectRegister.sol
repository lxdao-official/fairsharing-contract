// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IProjectRegister.sol";
import "./IProject.sol";

contract ProjectRegistry is Ownable, IProjectRegister {
    mapping(uint256 => address) public projects;
    mapping(uint256 => bytes32) public voteVerifiers;

    address public signer;

    constructor(address _signer) Ownable(_msgSender()) {
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

    function getProject(uint256 pid) external returns (address) {
        return projects[pid];
    }
}

contract Project is AccessControl, IProject {
    uint256 private pid;

    constructor(uint256 _pid, address manager) {
        grantRole(DEFAULT_ADMIN_ROLE, manager);
        pid = _pid;
    }

    function initialize() public {}

    function onPassMakeContribution() external returns (bool) {
        return true;
    }

    function onPassRevokeContribution() external returns (bool) {
        return true;
    }

    function onPassVerifyContribution() external returns (bool) {
        return true;
    }

    function onPassClaimContribution() external returns (bool) {
        return true;
    }
}
