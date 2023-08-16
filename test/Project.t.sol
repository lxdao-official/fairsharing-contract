// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ProjectRegister.sol";
import {ContributionResolver} from "../src/resolver/ContributionResolver.sol";
import {VoteResolver} from "../src/resolver/VoteResolver.sol";
import {ClaimResolver} from "../src/resolver/ClaimResolver.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/SchemaRegistry.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/EAS.sol";

contract ProjectTest is Test {
    address[] private _attesters;
    Merkle private _merkleTree;
    bytes32[] private _proofData;

    ISchemaRegistry private _schemaRegistry;
    IEAS private _eas;

    string private _contributionSchemaTemplate;
    string private _voteSchemaTemplate;
    string private _claimSchemaTemplate;

    ISchemaResolver private _contributionResolver;
    ISchemaResolver private _voteResolver;
    ISchemaResolver private _claimResolver;

    IProjectRegister private _registry;
    uint256[] projectIds;

    function setUp() public {
        for (uint256 i = 0; i < 10; i++) {
            address _addr = makeAddr(Strings.toString(i));
            _attesters.push(_addr);
        }

        _schemaRegistry = new SchemaRegistry();

        _eas = new EAS(ISchemaRegistry(_schemaRegistry));

        _registry = new ProjectRegistry(makeAddr("registry"));

        registerProject();
        registerSchemas();
    }

    //    function makeVoteMerkleTree() public {
    //        // Initialize
    //        Merkle m = new Merkle();
    //        // Toy Data
    //        bytes32[] memory data = new bytes32[](_attesters.length);
    //        for (uint256 i = 0; i < _attesters.length; i++) {
    //            data[i] = abi.encodePacked(_attesters[i]);
    //        }
    //        // Get Root, Proof, and Verify
    //        bytes32 root = m.getRoot(data);
    //
    //        bytes32[] memory proof = m.getProof(data, 2); // will get proof for 0x2 value
    //        bool verified = m.verifyProof(root, proof, data[2]); // true!
    //        assertTrue(verified);
    //    }

    function registerProject() public {
        // Initialize
        _merkleTree = new Merkle();
        // Toy Data
        _proofData = new bytes32[](_attesters.length);
        for (uint256 i = 0; i < _attesters.length; i++) {
            _proofData[i] = keccak256(abi.encodePacked(_attesters[i]));
        }
        // Get Root
        bytes32 root = _merkleTree.getRoot(_proofData);

        for (uint256 pid = 100; pid < 110; pid++) {
            address addr = makeAddr(Strings.toString(pid));
            _registry.register(pid, addr, root);
            projectIds.push(pid);
        }
    }

    function registerSchemas() public {
        _contributionResolver = new ContributionResolver(_eas, _registry);
        _voteResolver = new VoteResolver(_eas);
        _claimResolver = new ClaimResolver(_eas);

        _contributionSchemaTemplate = "uint256 pid, uint64 cid, string title, string detail, string poc, uint64 token, bytes32[] proof";

        //        console2.logBytes32(contributionSchemaId);
        _schemaRegistry.register(_contributionSchemaTemplate, _contributionResolver, true);

        //        SchemaRecord memory record = _schemaRegistry.getSchema(contributionSchemaId);
        //        assertEq(abi.encodePacked(record.uid), abi.encodePacked(_contributionSchemaTemplate));

        _voteSchemaTemplate = "uint256 pid, uint64 cid, bool value, string reason";
        bytes32 voteSchemaId = keccak256(
            abi.encodePacked(_contributionSchemaTemplate, _contributionResolver, true)
        );
        _schemaRegistry.register(_voteSchemaTemplate, _voteResolver, true);

        _claimSchemaTemplate = "uint256 pid, uint64 cid, string title, string detail, string poc, uint64 token";
        bytes32 claimSchemaId = keccak256(
            abi.encodePacked(_claimSchemaTemplate, _claimResolver, true)
        );
        _schemaRegistry.register(_claimSchemaTemplate, _claimResolver, true);
    }

    function testPrepareToVote() public {
        uint256 attesterIndex = 0;

        bytes32[] memory proof = _merkleTree.getProof(_proofData, attesterIndex); // will get proof for 0x2 value

        bytes memory customData = abi.encode(
            projectIds[0],
            uint64(1),
            "first contribution title",
            "first contribution detail",
            "the poc",
            uint64(2000),
            proof
        );

        AttestationRequestData memory data = AttestationRequestData({
            recipient: address(0),
            expirationTime: 0,
            revocable: true,
            refUID: "",
            data: customData,
            value: 0
        });

        AttestationRequest memory request = AttestationRequest({
            schema: keccak256(
                abi.encodePacked(_contributionSchemaTemplate, _contributionResolver, true)
            ),
            data: data
        });

        console2.log("---------------------- make attest ----------------------");
        console2.log(_attesters[attesterIndex]);
        vm.prank(_attesters[attesterIndex]);
        bytes32 contributionAttestationUid = _eas.attest(request);

        Attestation memory contributionAttestation = _eas.getAttestation(
            contributionAttestationUid
        );

        (
            uint256 pid,
            uint64 cid,
            string memory title,
            string memory detail,
            string memory poc,
            uint64 token
        ) = abi.decode(
                contributionAttestation.data,
                (uint256, uint64, string, string, string, uint64)
            );
        console2.log("--------------------------------------");
        console2.log("pid:%d \n  cid:%d \n  token:%d", pid, cid, token);
        console2.log("title:%s \n  detail:%s \n  poc:%s", title, detail, poc);
    }
}
