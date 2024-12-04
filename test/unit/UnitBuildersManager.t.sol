// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from '@oz/access/Ownable.sol';
import 'forge-std/StdJson.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import 'script/Registry.sol';
import {UnitBuildersManagerBase} from 'test/unit/UnitBuildersManagerBase.sol';

// TODO: add initial state tests to deploy test
contract UnitBuildersManagerTestInitialState is UnitBuildersManagerBase {
  function testInitialState() public view {
    IBuildersManager.BuilderManagerSettings memory _settings = buildersManager.settings();
    assertEq(_settings.cycleLength, 604_800);
    assertEq(_settings.lastClaimedTimestamp, 1_725_480_303);
    assertEq(_settings.currentSeasonExpiry, 1_741_032_303);
    assertEq(_settings.seasonDuration, 31_536_000);
    assertEq(_settings.minVouches, 3);
  }

  function testRegistry() public view {
    assertEq(address(buildersManager.TOKEN()), ANVIL_BUILDERS_DOLLAR);
    assertEq(address(buildersManager.EAS()), ANVIL_EAS);
  }

  function testInitialCurrentProjects() public view {
    address[] memory _projects = buildersManager.currentProjects();
    assertEq(_projects.length, 0);
  }

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

  function setUp() public override {
    super.setUp();
  }

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

contract UnitBuildersManagerTestDistributeYield is UnitBuildersManagerBase {}
