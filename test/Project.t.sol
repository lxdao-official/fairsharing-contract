// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/project/ProjectRegister.sol";
import "../src/project/Project.sol";
import {ContributionResolver} from "../src/resolver/ContributionResolver.sol";
import {VoteResolver} from "../src/resolver/VoteResolver.sol";
import {ClaimResolver} from "../src/resolver/ClaimResolver.sol";
import {AllocateResolver} from "../src/resolver/AllocateResolver.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/SchemaRegistry.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/EAS.sol";
import "../src/votingStrategy/DefaultRelativeVotingStrategy.sol";
import "../src/votingStrategy/IVotingStrategy.sol";
import "../src/upgrade/ProjectRegisterUpgradeableProxy.sol";

contract ProjectTest is Test {
    address[] private _attesters;
    uint256[] private _attesterPrivateKeys;

    ISchemaRegistry private _schemaRegistry;
    IEAS private _eas;

    address private _signer;
    uint256 private _signerPrivateKey;

    string private _contributionSchemaTemplate;
    string private _voteSchemaTemplate;
    string private _claimSchemaTemplate;
    string private _allocationSchemaTemplate;

    ISchemaResolver private _contributionResolver;
    ISchemaResolver private _voteResolver;
    ISchemaResolver private _claimResolver;
    ISchemaResolver private _allocationResolver;

    IProjectRegister private _registry;
    address[] projectAddresses;

    address votingStrategy;

    //    address votingWeightStrategy;

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

        DefaultRelativeVotingStrategy strategy = new DefaultRelativeVotingStrategy();
        votingStrategy = address(strategy);

        //        VotingWeightStrategy strategy1 = new VotingWeightStrategy();
        //        votingWeightStrategy = address(strategy1);

        ProjectToken _token = new ProjectToken();
        tokenTemplate = address(_token);

        address _owner = makeAddr("registryOwner");
        (_signer, _signerPrivateKey) = makeAddrAndKey("registry");
        _registry = new ProjectRegistry();
        _registry.initialize(_owner, _signer, address(_template), address(_token));

        registerProject();
        registerSchemas();
    }

    function registerProject() private {
        uint256[] memory weights = new uint256[](_attesters.length);
        weights[0] = 10;
        weights[1] = 10;
        weights[2] = 10;
        weights[3] = 10;
        weights[4] = 10;
        weights[5] = 10;
        weights[6] = 10;
        weights[7] = 10;
        weights[8] = 10;
        weights[9] = 10;

        for (uint256 i = 100; i < 110; i++) {
            address admin = _attesters[0];

            address[] memory adminList = new address[](1);
            adminList[0] = admin;

            bytes memory emptyData = abi.encode("");
            //            bytes memory votingStrategyData = abi.encode(_attesters, weights);

            CreateParams memory params = CreateParams({
                members: _attesters,
                admins: adminList,
                tokenName: "ProjectName",
                tokenSymbol: "FairSharingToken",
                voteStrategy: votingStrategy,
                voteWeights: weights,
                voteStrategyData: emptyData,
                voteThreshold: 50
            });

            vm.startPrank(admin);
            address projectAddress = _registry.create(params);
            vm.stopPrank();

            address latestProject = _registry.getOwnerLatestProject(admin, 0, i - 100);
            assert(projectAddress == latestProject);
            projectAddresses.push(projectAddress);
        }
    }

    function registerSchemas() private {
        _contributionResolver = new ContributionResolver(_eas);
        _voteResolver = new VoteResolver(_eas);
        _claimResolver = new ClaimResolver(_eas);
        _allocationResolver = new AllocateResolver(_eas);

        _contributionSchemaTemplate = "address ProjectAddress, bytes32 ContributionID, string Details, string Type, string Proof, uint256 StartDate, uint256 EndDate, uint256 TokenAmount, string Extended";
        _schemaRegistry.register(_contributionSchemaTemplate, _contributionResolver, true);

        _voteSchemaTemplate = "address ProjectAddress, bytes32 ContributionID, uint8 VoteChoice, string Comment";
        _schemaRegistry.register(_voteSchemaTemplate, _voteResolver, true);

        _claimSchemaTemplate = "address ProjectAddress, bytes32 ContributionID, address[] Voters, uint8[] VoteChoices, address Recipient, uint256 TokenAmount, bytes Signatures";
        _schemaRegistry.register(_claimSchemaTemplate, _claimResolver, false);

        _allocationSchemaTemplate = "address ProjectAddress, string title, address[] walletAddresses, uint16[] allocationRatios, uint256[] tokenAmounts";
        _schemaRegistry.register(_allocationSchemaTemplate, _allocationResolver, true);
    }

    function prepare(
        address attester,
        address projectAddress,
        bytes32 cid,
        uint256 token
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
                        "contribution detail",
                        "contribution type",
                        "the poc",
                        0,
                        0,
                        token,
                        "Extended"
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
        bytes32 cid,
        uint8 value,
        string memory comment
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
                    data: abi.encode(projectAddress, cid, value, comment),
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
        bytes32 cid;
        address attester;
        address receiver;
        uint256 token;
        uint8[] values;
    }

    function claim(ClaimParams memory params) private returns (bytes32 claimAttestationUid) {
        bytes32 hash = keccak256(
            abi.encode(block.chainid, params.attester, params.receiver, params.cid)
        );
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
            params.receiver,
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

    function testSetMembers() public {
        address projectAddress = projectAddresses[0];

        address admin = makeAddr("123");
        address[] memory addAdminList = new address[](1);
        addAdminList[0] = admin;

        address[] memory removeAdminList = new address[](1);
        removeAdminList[0] = _attesters[0];

        address member = makeAddr("456");
        address[] memory addMemberList = new address[](2);
        addMemberList[0] = admin;
        addMemberList[1] = member;

        address[] memory removeMemberList = new address[](1);
        removeMemberList[0] = _attesters[1];

        assert(IProject(projectAddress).isAdmin(_attesters[0]) == true);
        assert(IProject(projectAddress).isMember(_attesters[1]) == true);

        vm.startPrank(_attesters[0]);
        IProject(projectAddress).setMembers(
            addAdminList,
            removeAdminList,
            addMemberList,
            removeMemberList
        );
        vm.stopPrank();

        assert(IProject(projectAddress).isAdmin(admin) == true);

        assert(IProject(projectAddress).isAdmin(_attesters[0]) == false);

        assert(IProject(projectAddress).isMember(admin) == true);

        assert(IProject(projectAddress).isMember(_attesters[1]) == false);
    }

    function testPrepareContribution() public {
        address projectAddress = projectAddresses[0];

        bytes32 cid = keccak256(abi.encodePacked(block.chainid, uint256(123)));

        uint256 token = 2000;
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

        bytes32 cid = keccak256(abi.encodePacked(block.chainid, uint256(123)));

        uint256 token = 2000;
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
        bytes32 cid = keccak256(abi.encodePacked(block.chainid, uint256(123)));
        uint256 token = 1 ether;
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
        values[2] = 3;
        values[3] = 1;
        values[4] = 2;
        values[5] = 1;
        values[6] = 1;
        values[7] = 2;
        values[8] = 2;
        values[9] = 3;

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
        address receiver = makeAddr("token receiver");

        bytes32 claimAttestationUid = claim(
            ClaimParams(projectAddress, cid, _attesters[attesterIndex], receiver, token, values)
        );
        {
            console2.log("claim uid:");
            console2.logBytes32(claimAttestationUid);

            address tokenContract = IProject(projectAddress).getToken();
            uint256 amount = IERC20Upgradeable(tokenContract).balanceOf(receiver);
            console2.log("attester token amount: %d", amount);
        }
    }

    function testAllocate() public {
        address projectAddress = projectAddresses[0];
        address attester = _attesters[0];

        uint16[] memory allocationRatios = new uint16[](_attesters.length);
        uint256[] memory tokenAmounts = new uint256[](_attesters.length);
        for (uint256 i = 0; i < _attesters.length; i++) {
            allocationRatios[i] = 1000;
            tokenAmounts[i] = 1500 gwei;
        }

        vm.startPrank(attester);
        bytes32 uid = _eas.attest(
            AttestationRequest({
                schema: keccak256(
                    abi.encodePacked(_allocationSchemaTemplate, _allocationResolver, true)
                ),
                data: AttestationRequestData({
                    recipient: attester,
                    expirationTime: 0,
                    revocable: true,
                    refUID: "",
                    data: abi.encode(
                        projectAddress,
                        "title",
                        _attesters,
                        allocationRatios,
                        tokenAmounts
                    ),
                    value: 0
                })
            })
        );
        vm.stopPrank();

        console2.log("allocate uid:");
        console2.logBytes32(uid);
    }
}
