// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from '@oz/access/Ownable.sol';
import 'forge-std/StdJson.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import 'script/Registry.sol';
import {UnitBuildersManagerBase} from 'test/unit/UnitBuildersManagerBase.sol';

// TODO: add tests for individual attributes of attestations
contract UnitBuildersManagerTestInitialState is UnitBuildersManagerBase {
  /// @notice test the initial state
  function testInitialState() public view {
    IBuildersManager.BuilderManagerSettings memory _settings = buildersManager.settings();
    assertEq(_settings.cycleLength, 604_800);
    assertEq(_settings.lastClaimedTimestamp, 1_725_480_303);
    assertEq(_settings.currentSeasonExpiry, 1_741_032_303);
    assertEq(_settings.seasonDuration, 31_536_000);
    assertEq(_settings.minVouches, 3);
  }

  /// @notice test the registry addresses
  function testRegistry() public view {
    assertEq(address(buildersManager.TOKEN()), ANVIL_BUILDERS_DOLLAR);
    assertEq(address(buildersManager.EAS()), ANVIL_EAS);
  }

  /// @notice test the initial current projects
  function testInitialCurrentProjects() public view {
    address[] memory _projects = buildersManager.currentProjects();
    assertEq(_projects.length, 0);
  }

  /// @notice test the initial OP Foundation Attesters
  function testInitialOpFoundationAttesters() public view {
    address[] memory _opAttesters = buildersManager.optimismFoundationAttesters();
    assertEq(_opAttesters.length, 3);
  }
}

contract UnitBuildersManagerTestAccessControl is UnitBuildersManagerBase {
  address public newOpFoundationAttester1 = makeAddr('newOpFoundationAttester1');
  address public newOpFoundationAttester2 = makeAddr('newOpFoundationAttester2');

  address[] public newOpFoundationAttesters = [newOpFoundationAttester1, newOpFoundationAttester2];
  bool[] public newOpFoundationAttesterStatuses = [true, true];

  /// @notice test the owner
  function testOwner() public view {
    assertEq(Ownable(address(buildersManager)).owner(), owner);
  }

  /// @notice test updating an OP Foundation Attester
  function testUpdateOpFoundationAttester() public {
    vm.prank(owner);
    buildersManager.updateOpFoundationAttester(newOpFoundationAttester1, true);

    assertTrue(buildersManager.optimismFoundationAttester(newOpFoundationAttester1));
  }

  /// @notice test updating an OP Foundation Attester that is already verified
  function testUpdateOpFoundationAttesterDoubleVerify() public {
    vm.startPrank(owner);
    buildersManager.updateOpFoundationAttester(newOpFoundationAttester1, true);
    assertTrue(buildersManager.optimismFoundationAttester(newOpFoundationAttester1));

    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.AlreadyUpdated.selector, newOpFoundationAttester1));
    buildersManager.updateOpFoundationAttester(newOpFoundationAttester1, true);
  }

  /// @notice test updating an OP Foundation Attester that is not the owner
  function testUpdateOpFoundationAttesterRevertNotOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    buildersManager.updateOpFoundationAttester(newOpFoundationAttester1, true);
  }

  /// @notice test updating multiple OP Foundation Attesters
  function testUpdateOpFoundationAttesters() public {
    vm.prank(owner);
    buildersManager.batchUpdateOpFoundationAttesters(newOpFoundationAttesters, newOpFoundationAttesterStatuses);
    assertTrue(buildersManager.optimismFoundationAttester(newOpFoundationAttester1));
    assertTrue(buildersManager.optimismFoundationAttester(newOpFoundationAttester2));
  }

  /// @notice test updating multiple OP Foundation Attesters where one is already verified
  function testUpdateOpFoundationAttestersRevertStatusAlreadySet() public {
    newOpFoundationAttesterStatuses = [true, false];
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.AlreadyUpdated.selector, newOpFoundationAttester2));
    buildersManager.batchUpdateOpFoundationAttesters(newOpFoundationAttesters, newOpFoundationAttesterStatuses);
  }

  /// @notice test updating multiple OP Foundation Attesters where the caller is not the owner
  function testUpdateOpFoundationAttestersRevertNotOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    buildersManager.batchUpdateOpFoundationAttesters(newOpFoundationAttesters, newOpFoundationAttesterStatuses);
  }

  /// @notice test modifying the parameters
  function testModifyParams() public {
    IBuildersManager.BuilderManagerSettings memory _settings = buildersManager.settings();
    assertEq(_settings.cycleLength, 604_800);
    assertEq(_settings.lastClaimedTimestamp, 1_725_480_303);
    assertEq(_settings.currentSeasonExpiry, 1_741_032_303);
    assertEq(_settings.seasonDuration, 31_536_000);
    assertEq(_settings.minVouches, 3);

    uint256 _testValue = 100;
    vm.startPrank(owner);
    buildersManager.modifyParams(bytes32('cycleLength'), _testValue);
    buildersManager.modifyParams(bytes32('lastClaimedTimestamp'), _testValue);
    buildersManager.modifyParams(bytes32('currentSeasonExpiry'), _testValue);
    buildersManager.modifyParams(bytes32('seasonDuration'), _testValue);
    buildersManager.modifyParams(bytes32('minVouches'), _testValue);
    vm.stopPrank();

    _settings = buildersManager.settings();
    assertEq(_settings.cycleLength, _testValue);
    assertEq(_settings.lastClaimedTimestamp, _testValue);
    assertEq(_settings.currentSeasonExpiry, _testValue);
    assertEq(_settings.seasonDuration, _testValue);
    assertEq(_settings.minVouches, _testValue);
  }

  /// @notice test modifying the parameters where the value is zero
  function testModifyParamsRevertZeroValue() public {
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.ZeroValue.selector));
    buildersManager.modifyParams(bytes32('cycleLength'), 0);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.ZeroValue.selector));
    buildersManager.modifyParams(bytes32('lastClaimedTimestamp'), 0);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.ZeroValue.selector));
    buildersManager.modifyParams(bytes32('currentSeasonExpiry'), 0);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.ZeroValue.selector));
    buildersManager.modifyParams(bytes32('seasonDuration'), 0);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.ZeroValue.selector));
    buildersManager.modifyParams(bytes32('minVouches'), 0);
    vm.stopPrank();
  }

  /// @notice test modifying the parameters where the param is incorrect
  function testModifyParamsRevertWrongParam() public {
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.InvalidParamBytes32.selector, bytes32('wrongParam')));
    buildersManager.modifyParams(bytes32('wrongParam'), 100);
    vm.stopPrank();
  }
}

contract UnitBuildersManagerTestVouch is UnitBuildersManagerBase {
  /// @notice test offchain attestation creation
  function testOffchainAttestationCreation() public view {
    assertEq(offchainAttestation.version, 1);
    assertEq(offchainAttestation.attester, ANVIL_FOUNDATION_ATTESTER_3);
  }

  /**
   * @notice test vouch where:
   * - identity attestation is valid, but not verified
   * - project attestation is valid, but not verified
   */
  function testVouchAndVerifyIdentityAndProject() public {
    _mockVerifyIdentityAttestation(identityAttestation1);
    _mockVerifyProjectAttestation();

    assertEq(buildersManager.eligibleProject(offchainAttestationHash), address(0));

    vm.prank(ANVIL_VOTER_1);
    buildersManager.vouch(offchainAttestation, identityAttestation1.uid);

    assertTrue(buildersManager.eligibleProject(offchainAttestationHash) != address(0));
  }

  /**
   * @notice test vouch where:
   * - identity attestation is already verified
   * - project attestation is already verified
   */
  function testVouchWithNoVerification() public {
    _mockVerifyIdentityAttestation(identityAttestation1);
    _mockVerifyProjectAttestation();

    vm.prank(ANVIL_VOTER_1);
    buildersManager.vouch(offchainAttestation, identityAttestation1.uid);

    _mockVerifyIdentityAttestation(identityAttestation2);

    address _project = buildersManager.eligibleProject(offchainAttestationHash);
    assertEq(buildersManager.projectToVouches(_project), 1);

    vm.startPrank(ANVIL_VOTER_2);
    assertTrue(buildersManager.validateOptimismVoter(identityAttestation2.uid));
    buildersManager.vouch(offchainAttestationHash);
    vm.stopPrank();

    assertEq(buildersManager.projectToVouches(_project), 2);
  }

  /**
   * @notice test vouch where:
   * - identity attestation is already verified
   * - project attestation is valid, but not verified
   */
  function testVouchAndVerifyProject() public {
    _mockVerifyIdentityAttestation(identityAttestation1);
    _mockVerifyProjectAttestation();

    vm.startPrank(ANVIL_VOTER_1);
    assertTrue(buildersManager.validateOptimismVoter(identityAttestation1.uid));
    buildersManager.vouch(offchainAttestation);
    vm.stopPrank();

    address _project = buildersManager.eligibleProject(offchainAttestationHash);
    assertEq(buildersManager.projectToVouches(_project), 1);
  }

  /**
   * @notice test vouch where:
   * - identity attestation is valid, but not verified
   * - project attestation is already verified
   */
  function testVouchAndVerifyIdentity() public {
    _mockVerifyIdentityAttestation(identityAttestation1);
    _mockVerifyProjectAttestation();

    vm.prank(ANVIL_VOTER_1);
    buildersManager.vouch(offchainAttestation, identityAttestation1.uid);

    _mockVerifyIdentityAttestation(identityAttestation2);

    address _project = buildersManager.eligibleProject(offchainAttestationHash);
    assertEq(buildersManager.projectToVouches(_project), 1);

    vm.prank(ANVIL_VOTER_2);
    buildersManager.vouch(offchainAttestationHash, identityAttestation2.uid);

    assertEq(buildersManager.projectToVouches(_project), 2);
  }

  /// @notice test vouch where the identity attestation is invalid
  function testVouchRevertInvalidIdentityAttestation() public {
    _mockVerifyIdentityAttestation(identityAttestation1);

    vm.startPrank(ANVIL_VOTER_2);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.InvalidIdAttestation.selector));
    buildersManager.vouch(offchainAttestation, identityAttestation1.uid);
    vm.stopPrank();
  }

  /// @notice test vouch where the project attestation is invalid
  function testVouchRevertInvalidProjectAttestation() public {
    _mockVerifyIdentityAttestation(identityAttestation1);

    vm.startPrank(ANVIL_VOTER_1);
    vm.expectRevert();
    buildersManager.vouch(offchainAttestation, identityAttestation1.uid);
    vm.stopPrank();
  }

  /// @notice test vouch where the voter is not verified
  function testVouchRevertUnverifiedVoter() public {
    _mockVerifyIdentityAttestation(identityAttestation1);

    vm.startPrank(ANVIL_VOTER_1);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.IdAttestationRequired.selector));
    buildersManager.vouch(offchainAttestationHash);
    vm.stopPrank();
  }

  /// @notice test vouch where the project attestation hash is invalid
  function testVouchRevertInvalidProjectAttestationHash() public {
    _mockVerifyIdentityAttestation(identityAttestation1);

    vm.startPrank(ANVIL_VOTER_1);
    assertTrue(buildersManager.validateOptimismVoter(identityAttestation1.uid));
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.InvalidProjectAttestation.selector));
    buildersManager.vouch(offchainAttestationHash);
    vm.stopPrank();
  }

  /// @notice test double vouching for the same project
  function testVouchRevertAlreadyVouched() public {
    _mockVerifyIdentityAttestation(identityAttestation1);
    _mockVerifyProjectAttestation();

    vm.startPrank(ANVIL_VOTER_1);
    buildersManager.vouch(offchainAttestation, identityAttestation1.uid);

    address _project = buildersManager.eligibleProject(offchainAttestationHash);
    assertEq(buildersManager.projectToVouches(_project), 1);

    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.AlreadyVouched.selector));
    buildersManager.vouch(offchainAttestationHash);
    vm.stopPrank();

    assertEq(buildersManager.projectToVouches(_project), 1);
  }
}

contract VariablesForHarness {
  bytes32 public projectAttestationHash1 = keccak256('projectAttestationHash1');
  bytes32 public projectAttestationHash2 = keccak256('projectAttestationHash2');
  bytes32 public projectAttestationHash3 = keccak256('projectAttestationHash3');

  address public voter1 = address(uint160(uint256(keccak256('voter1'))));
  address public voter2 = address(uint160(uint256(keccak256('voter2'))));
  address public voter3 = address(uint160(uint256(keccak256('voter3'))));
  address public voter4 = address(uint160(uint256(keccak256('voter4'))));

  address public attacker = address(uint160(uint256(keccak256('attacker'))));
  bytes32 public invalidProjectAttestationHash = keccak256('invalidProjectAttestationHash');

  address[] public eligibleVoters = [voter1, voter2, voter3, voter4];
  bytes32[] public eligibleProjects = [projectAttestationHash1, projectAttestationHash2, projectAttestationHash3];
}

contract UnitBuildersManagerTestVouchWithHarness is UnitBuildersManagerBase, VariablesForHarness {
  function setUp() public override {
    super.setUp();
    buildersManagerHarness.populateEligibleProjects(eligibleProjects);
    buildersManagerHarness.populateEligibleVoters(eligibleVoters);
  }

  /// @notice test the initial state
  function testInitialState() public view {
    assertTrue(buildersManagerHarness.eligibleProject(projectAttestationHash1) != address(0));
    assertTrue(buildersManagerHarness.eligibleProject(projectAttestationHash2) != address(0));
    assertTrue(buildersManagerHarness.eligibleProject(projectAttestationHash3) != address(0));

    assertTrue(buildersManagerHarness.eligibleVoter(voter1));
    assertTrue(buildersManagerHarness.eligibleVoter(voter2));
    assertTrue(buildersManagerHarness.eligibleVoter(voter3));
    assertTrue(buildersManagerHarness.eligibleVoter(voter4));

    assertFalse(buildersManagerHarness.eligibleVoter(attacker));
    assertTrue(buildersManagerHarness.eligibleProject(invalidProjectAttestationHash) == address(0));

    address[] memory _currentProjects = buildersManagerHarness.currentProjects();
    assertEq(_currentProjects.length, 0);
  }

  /// @notice test adding a project after the minimum vouches
  function testAddProjectAfterMinimumVouches() public {
    vm.prank(voter1);
    buildersManagerHarness.vouch(projectAttestationHash1);

    vm.prank(voter2);
    buildersManagerHarness.vouch(projectAttestationHash1);

    address[] memory _currentProjectsAfter2Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter2Votes.length, 0);

    vm.prank(voter3);
    buildersManagerHarness.vouch(projectAttestationHash1);

    address[] memory _currentProjectsAfter3Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter3Votes.length, 1);
    assertEq(_currentProjectsAfter3Votes[0], address(buildersManagerHarness.eligibleProject(projectAttestationHash1)));

    vm.prank(voter4);
    buildersManagerHarness.vouch(projectAttestationHash1);

    address[] memory _currentProjectsAfter4Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter4Votes.length, _currentProjectsAfter3Votes.length);
  }

  /// @notice test adding a project after the minimum vouches for multiple projects
  function testAddProjectAfterMinimumVouchesForMultipleProjects() public {
    vm.startPrank(voter1);
    buildersManagerHarness.vouch(projectAttestationHash1);
    buildersManagerHarness.vouch(projectAttestationHash2);
    buildersManagerHarness.vouch(projectAttestationHash3);
    vm.stopPrank();

    vm.startPrank(voter2);
    buildersManagerHarness.vouch(projectAttestationHash1);
    buildersManagerHarness.vouch(projectAttestationHash2);
    buildersManagerHarness.vouch(projectAttestationHash3);
    vm.stopPrank();

    vm.startPrank(voter3);
    buildersManagerHarness.vouch(projectAttestationHash1);
    buildersManagerHarness.vouch(projectAttestationHash2);
    buildersManagerHarness.vouch(projectAttestationHash3);
    vm.stopPrank();

    address[] memory _currentProjectsAfter3X3Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter3X3Votes.length, 3);
  }

  /// @notice test distributing yield when there are no projects
  function testDistributeYieldRevertNoProjects() public {
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.YieldNoProjects.selector));
    buildersManagerHarness.distributeYield();
  }

  /// @notice test distributing yield after the cycle is ready
  function testDistributeYieldRevertAfterCycleReady() public {
    buildersManagerHarness.populateCurrentProjects(eligibleProjects);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.CycleNotReady.selector));
    buildersManagerHarness.distributeYield();
  }
}

// TODO: setup the builders dollar and add tests for the yield distribution
contract UnitBuildersManagerTestYieldDistributionWithHarness is UnitBuildersManagerBase, VariablesForHarness {
  modifier setupCycleReady() {
    buildersManagerHarness.populateCurrentProjects(eligibleProjects);
    vm.warp(buildersManagerHarness.settings().lastClaimedTimestamp + buildersManagerHarness.settings().cycleLength);
    _;
  }

  /// @notice test distributing yield when there are no projects
  function testDistributeYieldRevertNoProjects() public {
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.YieldNoProjects.selector));
    buildersManagerHarness.distributeYield();
  }

  /// @notice test distributing yield before the cycle is ready
  function testDistributeYieldRevertBeforeCycleReady() public {
    buildersManagerHarness.populateCurrentProjects(eligibleProjects);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.CycleNotReady.selector));
    buildersManagerHarness.distributeYield();
  }
}
