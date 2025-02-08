// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {BaseTest} from './BaseTest.sol';
import {Ownable} from '@oz/access/Ownable.sol';
import {IBuildersManager} from 'contracts/BuildersManager.sol';

contract UnitParameterTest is BaseTest {
  bytes32 public constant CYCLE_LENGTH = 'cycleLength';
  bytes32 public constant MIN_VOUCHES = 'minVouches';
  bytes32 public constant SEASON_DURATION = 'seasonDuration';
  bytes32 public constant CURRENT_SEASON_EXPIRY = 'currentSeasonExpiry';

  function test_ModifyParamsWhenCalledWithValidValues() public {
    IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 7 days,
      lastClaimedTimestamp: uint64(block.timestamp),
      currentSeasonExpiry: uint64(block.timestamp + 90 days),
      seasonDuration: 90 days,
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    settings.optimismFoundationAttesters[0] = address(this);
    mockSettings(settings);

    // Test modifying cycle length
    uint256 newCycleLength = 14 days;
    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.ParameterModified(CYCLE_LENGTH, newCycleLength);
    buildersManager.modifyParams(CYCLE_LENGTH, newCycleLength);
    settings.cycleLength = uint64(newCycleLength);
    mockSettings(settings);
    assertEq(buildersManager.settings().cycleLength, newCycleLength);

    // Test modifying min vouches
    uint256 newMinVouches = 5;
    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.ParameterModified(MIN_VOUCHES, newMinVouches);
    buildersManager.modifyParams(MIN_VOUCHES, newMinVouches);
    settings.minVouches = newMinVouches;
    mockSettings(settings);
    assertEq(buildersManager.settings().minVouches, newMinVouches);

    // Test modifying season duration
    uint256 newSeasonDuration = 180 days;
    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.ParameterModified(SEASON_DURATION, newSeasonDuration);
    buildersManager.modifyParams(SEASON_DURATION, newSeasonDuration);
    settings.seasonDuration = newSeasonDuration;
    mockSettings(settings);
    assertEq(buildersManager.settings().seasonDuration, newSeasonDuration);

    // Test modifying current season expiry
    uint256 newSeasonExpiry = block.timestamp + 365 days;
    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.ParameterModified(CURRENT_SEASON_EXPIRY, newSeasonExpiry);
    buildersManager.modifyParams(CURRENT_SEASON_EXPIRY, newSeasonExpiry);
    settings.currentSeasonExpiry = uint64(newSeasonExpiry);
    mockSettings(settings);
    assertEq(buildersManager.settings().currentSeasonExpiry, newSeasonExpiry);
  }

  function test_ModifyParamsWhenCalledWithInvalidValues() public {
    // Test invalid cycle length (0)
    vm.expectRevert(IBuildersManager.ZeroValue.selector);
    buildersManager.modifyParams(CYCLE_LENGTH, 0);

    // Test invalid min vouches (0)
    vm.expectRevert(IBuildersManager.ZeroValue.selector);
    buildersManager.modifyParams(MIN_VOUCHES, 0);

    // Test invalid season duration (less than cycle length)
    vm.expectRevert(IBuildersManager.ZeroValue.selector);
    buildersManager.modifyParams(SEASON_DURATION, 0);

    // Test invalid current season expiry (less than cycle length)
    vm.expectRevert(IBuildersManager.ZeroValue.selector);
    buildersManager.modifyParams(CURRENT_SEASON_EXPIRY, 0);
  }

  function test_ModifyParamsWhenCalledWithInvalidParameter() public {
    bytes32 invalidParam = 'INVALID_PARAM';
    vm.expectRevert(IBuildersManager.InvalidParameter.selector);
    buildersManager.modifyParams(invalidParam, 100);
  }

  function test_ModifyParamsWhenCalledByNonOwner() public {
    address nonOwner = address(0x123);
    vm.prank(nonOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
    buildersManager.modifyParams(CYCLE_LENGTH, 14 days);
  }
}
