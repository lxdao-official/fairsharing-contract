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
        _voteResolver = new VoteResolver(_eas, _registry);
        _claimResolver = new ClaimResolver(_eas, _registry);

        _contributionSchemaTemplate = "uint256 pid, uint64 cid, string title, string detail, string poc, uint64 token, bytes32[] proof";
        _schemaRegistry.register(_contributionSchemaTemplate, _contributionResolver, true);

        _voteSchemaTemplate = "uint256 pid, uint64 cid, bool value, string reason, bytes32[] proof";
        _schemaRegistry.register(_voteSchemaTemplate, _voteResolver, true);

        _claimSchemaTemplate = "uint256 pid, uint64 cid, string title, string detail, string poc, uint64 token, bytes32[] proof";
        _schemaRegistry.register(_claimSchemaTemplate, _claimResolver, true);
    }

    function vote(
        bytes32 contributionAttestationUid,
        uint256 pid,
        uint64 cid,
        uint256 voteIndex,
        bool value,
        string memory reason
    ) public {
        console2.log("---------------------- make vote attest ----------------------");
        uint256 _voteIndex = voteIndex;

        vm.startPrank(_attesters[voteIndex]);
        bytes32 voteAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(abi.encodePacked(_voteSchemaTemplate, _voteResolver, true)),
                data: AttestationRequestData({
                    recipient: address(0),
                    expirationTime: 0,
                    revocable: true,
                    refUID: contributionAttestationUid,
                    data: abi.encode(
                        pid,
                        cid,
                        value,
                        reason,
                        _merkleTree.getProof(_proofData, _voteIndex)
                    ),
                    value: 0
                })
            })
        );
        vm.stopPrank();
        {
            console2.logBytes32(voteAttestationUid);
            console2.log(value);
        }
    }

    function testPrepareToVote() public {
        uint256 pid = projectIds[0];
        uint64 cid = uint64(123);

        console2.log("---------------------- make contribution attest ----------------------");
        uint256 contributorIndex = 0;

        vm.startPrank(_attesters[contributorIndex]);
        bytes32 contributionAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(
                    abi.encodePacked(_contributionSchemaTemplate, _contributionResolver, true)
                ),
                data: AttestationRequestData({
                    recipient: address(0),
                    expirationTime: 0,
                    revocable: true,
                    refUID: "",
                    data: abi.encode(
                        pid,
                        cid,
                        "first contribution title",
                        "first contribution detail",
                        "the poc",
                        uint64(2000),
                        _merkleTree.getProof(_proofData, contributorIndex)
                    ),
                    value: 0
                })
            })
        );
        vm.stopPrank();

        {
            console2.log("contribution uid:");
            console2.logBytes32(contributionAttestationUid);

            Attestation memory contributionAttestation = _eas.getAttestation(
                contributionAttestationUid
            );

            (
                uint256 _pid,
                uint64 _cid,
                string memory title,
                string memory detail,
                string memory poc,
                uint64 token
            ) = abi.decode(
                    contributionAttestation.data,
                    (uint256, uint64, string, string, string, uint64)
                );
            console2.log("pid:%d \n  cid:%d \n  token:%d", _pid, _cid, token);
            console2.log("title:%s \n  detail:%s \n  poc:%s", title, detail, poc);
        }

        vote(contributionAttestationUid, pid, cid, 0, true, "good contribution");
        vote(contributionAttestationUid, pid, cid, 1, false, "good contribution");
        vote(contributionAttestationUid, pid, cid, 2, true, "good contribution");
        vote(contributionAttestationUid, pid, cid, 3, false, "good contribution");
        vote(contributionAttestationUid, pid, cid, 4, true, "good contribution");
        vote(contributionAttestationUid, pid, cid, 5, false, "good contribution");
        vote(contributionAttestationUid, pid, cid, 6, true, "good contribution");
        vote(contributionAttestationUid, pid, cid, 7, false, "good contribution");
        vote(contributionAttestationUid, pid, cid, 8, true, "good contribution");
        vote(contributionAttestationUid, pid, cid, 9, true, "good contribution");

        //        console2.log("---------------------- make claim attest ----------------------");
        //        vm.startPrank(_attesters[voteIndex]);
        //        bytes32 claimAttestationUid = _eas.attest(
        //            AttestationRequest({
        //                schema: keccak256(abi.encodePacked(_voteSchemaTemplate, _voteResolver, true)),
        //                data: AttestationRequestData({
        //                    recipient: address(0),
        //                    expirationTime: 0,
        //                    revocable: true,
        //                    refUID: contributionAttestationUid,
        //                    data: abi.encode(
        //                        pid,
        //                        cid,
        //                        true,
        //                        "good contribution",
        //                        _merkleTree.getProof(_proofData, voteIndex)
        //                    ),
        //                    value: 0
        //                })
        //            })
        //        );
        //        vm.stopPrank();
        //        {
        //            console2.log("claim uid:");
        //            console2.logBytes32(claimAttestationUid);
        //        }
    }
}
