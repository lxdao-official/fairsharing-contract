// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IProject.sol";
import "./ProjectToken.sol";
import "./IProjectRegister.sol";
import "../votingStrategy/IVotingStrategy.sol";

contract Project is Ownable, AccessControl, IProject {
    /**
     * @dev Emitted when voting strategy changed.
     */
    event VotingStrategyChanged(address indexed operator, address indexed from, address indexed to);

    /**
     * @dev Emitted when voting strategy data changed.
     */
    event VotingStrategyDataChanged(address indexed operator, bytes dataFrom, bytes dataTo);

    using ECDSA for bytes32;

    address public register;

    mapping(address => bool) public members;

    IProjectToken public token;

    VotingStrategy public votingStrategy;

    // cid => owner
    mapping(uint64 => address) private claims;

    /**
     * @dev Constructors are replaced by initialize function
     */
    function initialize(InitializeParams calldata param) external {
        register = param.register;

        votingStrategy = param.votingStrategy;

        token = IProjectToken(param.token);

        address[] memory empty = new address[](0);
        _setMembers(param.members, empty);

        _transferOwnership(param.owner);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, param.owner);
    }

    /**
     * @dev Get claims
     */
    function getClaims(uint64 cid) external view returns (address) {
        return claims[cid];
    }

    /**
     * @dev Get project owner
     */
    function getOwner() external view returns (address) {
        return this.owner();
    }

    /**
     * @dev Get project token address
     */
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

    /**
     * @dev Update project members
     */
    function setMembers(
        address[] memory addList,
        address[] memory removeList
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMembers(addList, removeList);
    }

    /**
     * @dev Update project voting strategy
     */
    function updateVotingStrategy(address _votingStrategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_votingStrategy != address(0) && _votingStrategy != votingStrategy.addr) {
            emit VotingStrategyChanged(_msgSender(), votingStrategy.addr, _votingStrategy);
            votingStrategy.addr = _votingStrategy;
        }
    }

    /**
     * @dev Update project voting strategy data
     */
    function updateVotingStrategyData(bytes calldata data) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (keccak256(abi.encodePacked(data)) != keccak256(abi.encodePacked(votingStrategy.data))) {
            emit VotingStrategyDataChanged(_msgSender(), votingStrategy.data, data);
            votingStrategy.data = data;
        }
    }

    /**
     * @dev Version of the ProjectRegistry contract. Default: "1.0.0"
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Delegate - Verify attesting for contribute resolver
     */
    function onPassMakeContribution(Attestation calldata attestation) external view returns (bool) {
        require(members[attestation.attester] == true, "Make vote verify failed.");
        return true;
    }

    /**
     * @dev Delegate - Verify revoke for contribution resolver
     */
    function onPassRevokeContribution(
        Attestation calldata attestation
    ) external view returns (bool) {
        require(members[attestation.attester] == true, "Revoke vote verify failed.");
        return true;
    }

    /**
     * @dev Delegate - Verify attesting for voting resolver
     */
    function onPassVoteContribution(Attestation calldata attestation) external view returns (bool) {
        require(members[attestation.attester] == true, "Make vote verify failed.");
        return true;
    }

    /**
     * @dev Delegate - Verify attesting for claim resolver
     */
    function onPassClaimContribution(Attestation calldata attestation) external returns (bool) {
        address attester = attestation.attester;
        // verify member
        require(members[attester] == true, "Make vote verify failed.");

        (
            ,
            uint64 cid,
            address[] memory voters,
            uint8[] memory values,
            address receiver,
            uint256 amount,
            bytes memory signature
        ) = abi.decode(
                attestation.data,
                (address, uint64, address[], uint8[], address, uint256, bytes)
            );

        require(claims[cid] == address(0), "This contribution was claimed");

        // verify signature
        bytes32 hash = keccak256(abi.encode(block.chainid, attester, receiver, cid));
        require(
            hash.toEthSignedMessageHash().recover(signature) ==
                IProjectRegister(register).getSigner(),
            "Make claim verify signature failed"
        );

        // count votes
        bool result = IVotingStrategy(votingStrategy.addr).getResult(
            voters,
            values,
            votingStrategy.data,
            votingStrategy.passingRate
        );
        if (result) {
            // mint
            IProjectToken(token).mint(receiver, amount);

            // store
            claims[cid] = attester;
            return true;
        } else {
            return false;
        }
    }
}
