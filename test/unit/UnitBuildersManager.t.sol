// SPDX-License-Identifier: PPL
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
