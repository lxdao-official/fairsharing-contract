// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/project/ProjectRegister.sol";
import "../src/project/Project.sol";
import {ContributionResolver} from "../src/resolver/ContributionResolver.sol";
import {VoteResolver} from "../src/resolver/VoteResolver.sol";
import {ClaimResolver} from "../src/resolver/ClaimResolver.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
//import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
//import "murky/Merkle.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/SchemaRegistry.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/EAS.sol";
import "../src/votingStrategy/DefaultVotingStrategy.sol";
import "../src/votingStrategy/IVotingStrategy.sol";

contract ProjectTest is Test {
    address[] private _attesters;
    uint256[] private _attesterPrivateKeys;
    //    Merkle private _merkleTree;
    //    bytes32[] private _proofData;

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
    address[] projectAddresses;

    address votingStrategy;

    address tokenTemplate;

    function setUp() public {
        for (uint256 i = 0; i < 10; i++) {
            (address _addr, uint256 privateKey) = makeAddrAndKey(Strings.toString(i));
            _attesters.push(_addr);
            _attesterPrivateKeys.push(privateKey);
        }

        _schemaRegistry = new SchemaRegistry();

        _eas = new EAS(ISchemaRegistry(_schemaRegistry));

        Project _template = new Project();

        DefaultVotingStrategy strategy = new DefaultVotingStrategy();
        votingStrategy = address(strategy);

        ProjectToken _token = new ProjectToken();
        tokenTemplate = address(_token);

        (_signer, _signerPrivateKey) = makeAddrAndKey("registry");
        _registry = new ProjectRegistry(_signer, address(_template), address(_token));

        registerProject();
        registerSchemas();
    }

    function registerProject() private {
        //        // Initialize
        //        _merkleTree = new Merkle();
        //        // Toy Data
        //        _proofData = new bytes32[](_attesters.length);
        //        for (uint256 i = 0; i < _attesters.length; i++) {
        //            _proofData[i] = keccak256(abi.encodePacked(_attesters[i]));
        //        }

        for (uint256 i = 100; i < 110; i++) {
            address addr = makeAddr(Strings.toString(i));

            bytes memory votingStrategyData = abi.encode("");
            address projectAddress = _registry.create(
                addr,
                _attesters,
                "FairSharingToken",
                votingStrategy,
                votingStrategyData
            );

            address latestProject = _registry.getOwnerLatestProject(addr, 0, i - 100);
            assert(projectAddress == latestProject);

            projectAddresses.push(projectAddress);
        }
    }

    function testAAAA() public {}

    function registerSchemas() private {
        _contributionResolver = new ContributionResolver(_eas);
        _voteResolver = new VoteResolver(_eas);
        _claimResolver = new ClaimResolver(_eas);

        _contributionSchemaTemplate = "address projectAddress, uint64 cid, string title, string detail, string poc, uint64 token";
        _schemaRegistry.register(_contributionSchemaTemplate, _contributionResolver, true);

        _voteSchemaTemplate = "address projectAddress, uint64 cid, uint8 value, string reason";
        _schemaRegistry.register(_voteSchemaTemplate, _voteResolver, true);

        _claimSchemaTemplate = "address projectAddress, uint64 cid, address[] voters, uint8[] values, uint64 token, bytes signature";
        _schemaRegistry.register(_claimSchemaTemplate, _claimResolver, false);
    }

    function prepare(
        address attester,
        address projectAddress,
        uint64 cid,
        uint64 token
    ) private returns (bytes32 contributionAttestationUid) {
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
                        projectAddress,
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
    }

    function revokeContribution(address attester, bytes32 uid) private {
        vm.startPrank(attester);
        _eas.revoke(
            RevocationRequest({
                schema: keccak256(
                    abi.encodePacked(_contributionSchemaTemplate, _contributionResolver, true)
                ),
                data: RevocationRequestData({uid: uid, value: 0})
            })
        );
        vm.stopPrank();
    }

    function vote(
        bytes32 contributionAttestationUid,
        address attester,
        address projectAddress,
        uint64 cid,
        uint8 value,
        string memory reason
    ) private returns (bytes32 voteAttestationUid) {
        vm.startPrank(attester);
        voteAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(abi.encodePacked(_voteSchemaTemplate, _voteResolver, true)),
                data: AttestationRequestData({
                    recipient: address(0),
                    expirationTime: 0,
                    revocable: true,
                    refUID: contributionAttestationUid,
                    data: abi.encode(projectAddress, cid, value, reason),
                    value: 0
                })
            })
        );
        vm.stopPrank();
    }

    function revokeVote(bytes32 voteUid, address attester) private {
        vm.startPrank(attester);
        _eas.revoke(
            RevocationRequest({
                schema: keccak256(abi.encodePacked(_voteSchemaTemplate, _voteResolver, true)),
                data: RevocationRequestData({uid: voteUid, value: 0})
            })
        );
        vm.stopPrank();
    }

    struct ClaimParams {
        address projectAddress;
        uint64 cid;
        address attester;
        uint64 token;
        uint8[] values;
    }

    function claim(ClaimParams memory params) private returns (bytes32 claimAttestationUid) {
        bytes32 hash = keccak256(abi.encode(block.chainid, params.attester, params.cid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerPrivateKey,
            ECDSA.toEthSignedMessageHash(hash)
        );

        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory data = abi.encode(
            params.projectAddress,
            params.cid,
            _attesters,
            params.values,
            params.token,
            signature
        );

        vm.startPrank(params.attester);
        claimAttestationUid = _eas.attest(
            AttestationRequest({
                schema: keccak256(abi.encodePacked(_claimSchemaTemplate, _claimResolver, false)),
                data: AttestationRequestData({
                    recipient: params.attester,
                    expirationTime: 0,
                    revocable: false,
                    refUID: "",
                    data: data,
                    value: 0
                })
            })
        );
        vm.stopPrank();
    }

    function testPrepareContribution() public {
        address projectAddress = projectAddresses[0];
        uint64 cid = uint64(123);
        uint64 token = 2000;
        uint256 attesterIndex = 0;

        console2.log("---------------------- make contribution attest ----------------------");
        bytes32 contributionAttestationUid = prepare(
            _attesters[attesterIndex],
            projectAddress,
            cid,
            token
        );
        {
            console2.log("contribution uid:");
            console2.logBytes32(contributionAttestationUid);

            Attestation memory attestation = _eas.getAttestation(contributionAttestationUid);
            console2.log("revocation time:%d", attestation.revocationTime);
        }

        console2.log("---------------------- revoke contribution ----------------------");
        revokeContribution(_attesters[attesterIndex], contributionAttestationUid);
        {
            Attestation memory attestation = _eas.getAttestation(contributionAttestationUid);
            console2.log("revocation time:%d", attestation.revocationTime);
        }
    }

    function testVote() public {
        address projectAddress = projectAddresses[0];
        uint64 cid = uint64(123);
        uint64 token = 2000;
        uint256 attesterIndex = 0;
        bytes32 contributionAttestationUid = prepare(
            _attesters[attesterIndex],
            projectAddress,
            cid,
            token
        );

        uint8[] memory values = new uint8[](1);
        values[0] = 1;

        for (uint256 i = 0; i < values.length; i++) {
            console2.log("---------------------- make vote attest ----------------------");
            bytes32 voteAttestationUid = vote(
                contributionAttestationUid,
                _attesters[attesterIndex],
                projectAddress,
                cid,
                values[i],
                "good contribution"
            );
            {
                console2.log("vote:%d uid:", values[i]);
                console2.logBytes32(voteAttestationUid);

                Attestation memory attestation = _eas.getAttestation(voteAttestationUid);
                console2.log("revocation time:%d", attestation.revocationTime);
            }
            console2.log("---------------------- revoke vote ----------------------");
            revokeVote(voteAttestationUid, _attesters[attesterIndex]);
            {
                Attestation memory attestation = _eas.getAttestation(voteAttestationUid);
                console2.log("revocation time:%d", attestation.revocationTime);
            }
        }
    }

    function testClaim() public {
        address projectAddress = projectAddresses[0];
        uint64 cid = uint64(123);
        uint64 token = 2000;
        uint256 attesterIndex = 0;
        bytes32 contributionAttestationUid = prepare(
            _attesters[attesterIndex],
            projectAddress,
            cid,
            token
        );

        uint8[] memory values = new uint8[](_attesters.length);
        values[0] = 1;
        values[1] = 1;
        values[2] = 1;
        values[3] = 1;
        values[4] = 2;
        values[5] = 1;
        values[6] = 3;
        values[7] = 1;
        values[8] = 1;
        values[9] = 1;

        for (uint256 i = 0; i < values.length; i++) {
            vote(
                contributionAttestationUid,
                _attesters[attesterIndex],
                projectAddress,
                cid,
                values[i],
                "good contribution"
            );
        }
        console2.log("---------------------- make claim attest ----------------------");
        bytes32 claimAttestationUid = claim(
            ClaimParams(projectAddress, cid, _attesters[attesterIndex], token, values)
        );
        {
            console2.log("claim uid:");
            console2.logBytes32(claimAttestationUid);

            address tokenContract = IProject(projectAddress).getToken();
            uint256 amount = IERC20Upgradeable(tokenContract).balanceOf(_attesters[attesterIndex]);
            console2.log("attester token amount: %d", amount);
        }
    }
}
