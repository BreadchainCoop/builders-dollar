// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from '@oz/access/Ownable.sol';
import {IBuilderManager} from 'contracts/BuilderManager.sol';
import {BaseTest} from 'test/unit/BaseTest.sol';

contract UnitParameterTest is BaseTest {
  bytes32 public constant CYCLE_LENGTH = 'cycleLength';
  bytes32 public constant MIN_VOUCHES = 'minVouches';
  bytes32 public constant SEASON_DURATION = 'seasonDuration';
  bytes32 public constant SEASON_START = 'seasonStart';
  bytes32 public constant FUNDING_EXPIRY = 'fundingExpiry';

  function test_ModifyParamsWhenCalledWithValidValues() public {
    IBuilderManager.BuilderManagerSettings memory settings = IBuilderManager.BuilderManagerSettings({
      cycleLength: 30 days,
      lastClaimedTimestamp: uint64(block.timestamp),
      fundingExpiry: uint64(304 days),
      seasonStart: uint64(1_704_067_200),
      seasonDuration: uint64(365 days),
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    settings.optimismFoundationAttesters[0] = address(this);
    mockSettings(settings);

    // Test modifying cycle length
    uint256 newCycleLength = 14 days;
    vm.expectEmit(true, true, true, true);
    emit IBuilderManager.ParameterModified(CYCLE_LENGTH, newCycleLength);
    builderManager.modifyParams(CYCLE_LENGTH, newCycleLength);
    settings.cycleLength = uint64(newCycleLength);
    mockSettings(settings);
    assertEq(builderManager.settings().cycleLength, newCycleLength);

    // Test modifying min vouches
    uint256 newMinVouches = 5;
    vm.expectEmit(true, true, true, true);
    emit IBuilderManager.ParameterModified(MIN_VOUCHES, newMinVouches);
    builderManager.modifyParams(MIN_VOUCHES, newMinVouches);
    settings.minVouches = newMinVouches;
    mockSettings(settings);
    assertEq(builderManager.settings().minVouches, newMinVouches);

    // Test modifying funding expiry
    uint256 newFundingExpiry = 365 days;
    vm.expectEmit(true, true, true, true);
    emit IBuilderManager.ParameterModified(FUNDING_EXPIRY, newFundingExpiry);
    builderManager.modifyParams(FUNDING_EXPIRY, newFundingExpiry);
    settings.fundingExpiry = uint64(newFundingExpiry);
    mockSettings(settings);
    assertEq(builderManager.settings().fundingExpiry, newFundingExpiry);

    // Test modifying season start
    uint256 newSeasonStart = 1_704_067_200 + 30 days;
    vm.expectEmit(true, true, true, true);
    emit IBuilderManager.ParameterModified(SEASON_START, newSeasonStart);
    builderManager.modifyParams(SEASON_START, newSeasonStart);
    settings.seasonStart = uint64(newSeasonStart);
    mockSettings(settings);
    assertEq(builderManager.settings().seasonStart, newSeasonStart);

    // Test modifying season duration
    uint256 newSeasonDuration = 180 days;
    vm.expectEmit(true, true, true, true);
    emit IBuilderManager.ParameterModified(SEASON_DURATION, newSeasonDuration);
    builderManager.modifyParams(SEASON_DURATION, newSeasonDuration);
    settings.seasonDuration = uint64(newSeasonDuration);
    mockSettings(settings);
    assertEq(builderManager.settings().seasonDuration, newSeasonDuration);
  }

  function test_ModifyParamsWhenCalledWithInvalidValues() public {
    // Test invalid cycle length (0)
    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.modifyParams(CYCLE_LENGTH, 0);

    // Test invalid min vouches (0)
    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.modifyParams(MIN_VOUCHES, 0);

    // Test invalid funding expiry (0)
    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.modifyParams(FUNDING_EXPIRY, 0);

    // Test invalid season start (0)
    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.modifyParams(SEASON_START, 0);

    // Test invalid season duration (0)
    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.modifyParams(SEASON_DURATION, 0);
  }

  function test_ModifyParamsWhenCalledWithInvalidParameter() public {
    bytes32 invalidParam = 'INVALID_PARAM';
    vm.expectRevert(IBuilderManager.InvalidParameter.selector);
    builderManager.modifyParams(invalidParam, 100);
  }

  function test_ModifyParamsWhenCalledByNonOwner() public {
    address nonOwner = address(0x123);
    vm.prank(nonOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
    builderManager.modifyParams(CYCLE_LENGTH, 14 days);
  }
}
