// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../src/extensions/IAllocationPool.sol";
import "../src/extensions/AllocationPool.sol";
import "../src/project/Project.sol";
import "../src/project/ProjectRegister.sol";
import "../src/upgrade/ProjectRegisterUpgradeableProxy.sol";
import "../src/votingStrategy/DefaultRelativeVotingStrategy.sol";
import "../src/votingStrategy/IVotingStrategy.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/EAS.sol";

import "@ethereum-attestation-service/eas-contracts/contracts/SchemaRegistry.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Test.sol";
import {AllocationResolver} from "../src/resolver/AllocationResolver.sol";
import {ClaimResolver} from "../src/resolver/ClaimResolver.sol";
import {ContributionResolver} from "../src/resolver/ContributionResolver.sol";
import {VoteResolver} from "../src/resolver/VoteResolver.sol";

import "./TestToken.sol";

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

    IAllocationPoolFactory poolFactory;
    IAllocationPoolTemplate poolTemplate;

    function setUp() public {
        for (uint256 i = 0; i < 10; i++) {
            (address _addr, uint256 privateKey) = makeAddrAndKey(Strings.toString(i));
            _attesters.push(_addr);
            _attesterPrivateKeys.push(privateKey);

            vm.deal(address(_addr), 1 ether);
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

        poolTemplate = new AllocationPoolTemplate();
        poolFactory = new AllocationPoolFactory(address(poolTemplate));

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
        _allocationResolver = new AllocationResolver(_eas);

        _contributionSchemaTemplate = "address ProjectAddress, bytes32 ContributionID, string Details, string Type, string Proof, uint256 StartDate, uint256 EndDate, uint256 TokenAmount, string Extended";
        _schemaRegistry.register(_contributionSchemaTemplate, _contributionResolver, true);

        _voteSchemaTemplate = "address ProjectAddress, bytes32 ContributionID, uint8 VoteChoice, string Comment";
        _schemaRegistry.register(_voteSchemaTemplate, _voteResolver, true);

        _claimSchemaTemplate = "address ProjectAddress, bytes32 ContributionID, address[] Voters, uint8[] VoteChoices, address Recipient, uint256 TokenAmount, bytes Signatures";
        _schemaRegistry.register(_claimSchemaTemplate, _claimResolver, false);

        _allocationSchemaTemplate = "address ProjectAddress, string Title, address[] WalletAddresses, uint32[] AllocationRatios, uint256[] TokenAmounts";
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

    function testAllocation() public {
        address projectAddress = projectAddresses[0];
        address attester = _attesters[0];

        uint32[] memory allocationRatios = new uint32[](_attesters.length);
        uint256[] memory tokenAmounts = new uint256[](_attesters.length);
        for (uint256 i = 0; i < _attesters.length; i++) {
            allocationRatios[i] = 10_000_000;
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

    struct PreparePoolParams {
        address projectAddress;
        address attester;
        address depositor;
        address contributor;
        uint256 token0Amount;
        uint256 token1Amount;
    }

    function preparePool(
        PreparePoolParams memory params
    )
        public
        returns (
            TestToken token1,
            address poolAddress,
            address[] memory tokenAddresses,
            uint256[] memory amounts,
            uint256 average0Amount,
            uint256 average1Amount
        )
    {
        address projectAddress = params.projectAddress;
        address attester = params.attester;
        address depositor = params.depositor;
        //        address contributor = params.contributor;
        uint256 token0Amount = params.token0Amount;
        uint256 token1Amount = params.token1Amount;

        // token
        token1 = new TestToken("token1", "symbol1");
        token1.mint(depositor, token1Amount);

        // allocation
        tokenAddresses = new address[](2);
        tokenAddresses[0] = address(0);
        tokenAddresses[1] = address(token1);

        amounts = new uint256[](2);
        amounts[0] = token0Amount;
        amounts[1] = token1Amount;

        Allocation[] memory allocations = new Allocation[](2);
        allocations[0].token = tokenAddresses[0];
        allocations[1].token = tokenAddresses[1];
        allocations[0].unClaimedAmount = amounts[0];
        allocations[1].unClaimedAmount = amounts[1];

        average0Amount = token0Amount / _attesters.length;
        average1Amount = token1Amount / _attesters.length;

        {
            for (uint256 i = 0; i < allocations.length; i++) {
                allocations[i].addresses = _attesters;

                uint256[] memory tokenAmounts = new uint256[](_attesters.length);
                uint32[] memory ratios = new uint32[](_attesters.length);
                for (uint256 j = 0; j < _attesters.length; j++) {
                    if (i == 0) {
                        tokenAmounts[j] = average0Amount;
                    } else {
                        tokenAmounts[j] = average1Amount;
                    }
                    ratios[j] = 10_000_000;
                }
                allocations[i].tokenAmounts = tokenAmounts;
                allocations[i].ratios = ratios;
            }
        }

        ExtraParams memory params = ExtraParams({
            projectAddress: projectAddress,
            creator: attester,
            depositor: depositor,
            timeToClaim: block.timestamp + 30
        });
        poolAddress = poolFactory.create(allocations, params);
    }

    function testAllocationPool() public {
        address projectAddress = projectAddresses[0];
        address attester = _attesters[0];
        address depositor = _attesters[1];
        address contributor = _attesters[2];
        uint256 token0Amount = 1 ether;
        uint256 token1Amount = 15 ether;

        PreparePoolParams memory params = PreparePoolParams({
            projectAddress: projectAddress,
            attester: attester,
            depositor: depositor,
            contributor: contributor,
            token0Amount: token0Amount,
            token1Amount: token1Amount
        });
        (
            TestToken token1,
            address result,
            address[] memory tokenAddresses,
            uint256[] memory amounts,
            uint256 average0Amount,
            uint256 average1Amount
        ) = preparePool(params);

        IAllocationPoolTemplate pool = IAllocationPoolTemplate(result);

        // deposit
        vm.startPrank(depositor);
        token1.approve(address(pool), amounts[1]);
        pool.deposit{value: amounts[0]}(tokenAddresses, amounts);
        vm.stopPrank();

        // claim
        vm.warp(block.timestamp + 30);
        vm.startPrank(contributor);
        uint256 token0BalanceBefore = contributor.balance;
        uint256 token1BalanceBefore = token1.balanceOf(contributor);
        pool.claim();
        assert(contributor.balance == token0BalanceBefore + average0Amount);
        assert(token1.balanceOf(contributor) == token1BalanceBefore + average1Amount);
        vm.stopPrank();

        // refund
        //        vm.startPrank(depositor);
        //        pool.refund();
        //        assert(depositor.balance == token0Amount);
        //        assert(token1.balanceOf(depositor) == token1Amount);
        //        vm.stopPrank();
    }
}
