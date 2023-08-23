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
    uint256[] private _attesterPrivateKeys;
    Merkle private _merkleTree;
    bytes32[] private _proofData;

    ISchemaRegistry private _schemaRegistry;
    IEAS private _eas;

    address private _signer;
    uint256 private _signerPrivateKey;

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
            (address _addr, uint256 privateKey) = makeAddrAndKey(Strings.toString(i));
            _attesters.push(_addr);
            _attesterPrivateKeys.push(privateKey);
        }

        _schemaRegistry = new SchemaRegistry();

        _eas = new EAS(ISchemaRegistry(_schemaRegistry));

        (_signer, _signerPrivateKey) = makeAddrAndKey("registry");
        _registry = new ProjectRegistry(_signer);

        registerProject();
        registerSchemas();
    }

    function registerProject() private {
        // Initialize
        _merkleTree = new Merkle();
        // Toy Data
        _proofData = new bytes32[](_attesters.length);
        for (uint256 i = 0; i < _attesters.length; i++) {
            _proofData[i] = keccak256(abi.encodePacked(_attesters[i]));
        }
        // Get Root
        //        bytes32 root = _merkleTree.getRoot(_proofData);

        for (uint256 i = 100; i < 110; i++) {
            address addr = makeAddr(Strings.toString(i));
            (, uint256 pid) = _registry.register(addr, _attesters, "FairSharingToken");
            projectIds.push(pid);
        }
    }

    function registerSchemas() private {
        _contributionResolver = new ContributionResolver(_eas, _registry);
        _voteResolver = new VoteResolver(_eas, _registry);
        _claimResolver = new ClaimResolver(_eas, _registry);

        _contributionSchemaTemplate = "uint256 pid, uint64 cid, string title, string detail, string poc, uint64 token";
        _schemaRegistry.register(_contributionSchemaTemplate, _contributionResolver, true);

        _voteSchemaTemplate = "uint256 pid, uint64 cid , uint8 value, string reason";
        _schemaRegistry.register(_voteSchemaTemplate, _voteResolver, true);

        _claimSchemaTemplate = "uint256 pid, uint64 cid, address[] voters, uint8[] values, uint64 token, bytes signature";
        _schemaRegistry.register(_claimSchemaTemplate, _claimResolver, true);
    }

    function prepare(
        uint256 pid,
        uint64 cid,
        uint256 attesterIndex,
        uint64 token
    ) private returns (bytes32 contributionAttestationUid) {
        console2.log("---------------------- make contribution attest ----------------------");
        address attester = _attesters[attesterIndex];

        vm.startPrank(attester);
        contributionAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(
                    abi.encodePacked(_contributionSchemaTemplate, _contributionResolver, true)
                ),
                data: AttestationRequestData({
                    recipient: attester,
                    expirationTime: 0,
                    revocable: true,
                    refUID: "",
                    data: abi.encode(
                        pid,
                        cid,
                        "first contribution title",
                        "first contribution detail",
                        "the poc",
                        token
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
                uint64 _token
            ) = abi.decode(
                    contributionAttestation.data,
                    (uint256, uint64, string, string, string, uint64)
                );
            console2.log("pid:%d \n  cid:%d \n  token:%d", _pid, _cid, _token);
            console2.log("title:%s \n  detail:%s \n  poc:%s", title, detail, poc);
        }
    }

    function vote(
        bytes32 contributionAttestationUid,
        uint256 pid,
        uint64 cid,
        uint256 voteIndex,
        uint8 value,
        string memory reason
    ) private {
        console2.log("---------------------- make vote attest ----------------------");

        vm.startPrank(_attesters[voteIndex]);
        bytes32 voteAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(abi.encodePacked(_voteSchemaTemplate, _voteResolver, true)),
                data: AttestationRequestData({
                    recipient: address(0),
                    expirationTime: 0,
                    revocable: true,
                    refUID: contributionAttestationUid,
                    data: abi.encode(pid, cid, value, reason),
                    value: 0
                })
            })
        );
        vm.stopPrank();
        {
            console2.log("vote:%d uid:", value);
            console2.logBytes32(voteAttestationUid);
        }
    }

    struct ClaimParams {
        bytes32 uid;
        uint256 pid;
        uint64 cid;
        uint256 index;
        uint64 token;
        uint8[] values;
    }

    function claim(ClaimParams memory params) private {
        console2.log("---------------------- make claim attest ----------------------");
        address attester = _attesters[params.index];

        bytes32 hash = keccak256(abi.encode(attester, params.pid, params.cid, params.uid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory data = abi.encode(
            params.pid,
            params.cid,
            _attesters,
            params.values,
            params.token,
            signature
        );

        vm.startPrank(attester);
        bytes32 claimAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(abi.encodePacked(_claimSchemaTemplate, _claimResolver, true)),
                data: AttestationRequestData({
                    recipient: attester,
                    expirationTime: 0,
                    revocable: true,
                    refUID: params.uid,
                    data: data,
                    value: 0
                })
            })
        );
        vm.stopPrank();
        {
            console2.log("claim uid:");
            console2.logBytes32(claimAttestationUid);

            address project = _registry.getProject(params.pid);
            address token = IProject(project).getToken();
            uint256 amount = IERC20(token).balanceOf(attester);
            console2.log("attester token amount: %d", amount);
        }
    }

    function testPrepareToVote() public {
        uint256 pid = projectIds[0];
        uint64 cid = uint64(123);
        uint64 token = 2000;
        uint256 attesterIndex = 0;
        bytes32 contributionAttestationUid = prepare(pid, cid, attesterIndex, token);

        uint8[] memory values = new uint8[](_attesters.length);
        values[0] = 1;
        values[1] = 1;
        values[2] = 2;
        values[3] = 1;
        values[4] = 2;
        values[5] = 1;
        values[6] = 3;
        values[7] = 1;
        values[8] = 1;
        values[9] = 1;

        for (uint256 i = 0; i < values.length; i++) {
            vote(contributionAttestationUid, pid, cid, i, values[i], "good contribution");
        }

        claim(ClaimParams(contributionAttestationUid, pid, cid, attesterIndex, token, values));
    }
}
