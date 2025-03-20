// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BaseTest} from './BaseTest.sol';
import {Initializable} from '@oz-upgradeable/proxy/utils/Initializable.sol';
import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';

contract UnitInitializationTest is BaseTest {
  function test_InitializeWhenPassingValidSettings() external {
    // Deploy implementation
    BuildersManager implementation = new BuildersManager();

    // Create settings
    IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 30 days,
      lastClaimedTimestamp: uint64(block.timestamp),
      fundingExpiry: uint64(304 days),
      seasonStart: uint64(1_704_067_200),
      seasonDuration: uint64(365 days),
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    settings.optimismFoundationAttesters[0] = address(this);

    // Deploy proxy and initialize
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(implementation),
      address(this),
      abi.encodeWithSelector(IBuildersManager.initialize.selector, token, eas, 'BuildersManager', '1', settings)
    );

    // Cast proxy to BuildersManager interface
    IBuildersManager newManager = IBuildersManager(address(proxy));

    // Verify settings were initialized correctly
    IBuildersManager.BuilderManagerSettings memory actualSettings = newManager.settings();
    assertEq(actualSettings.cycleLength, settings.cycleLength);
    assertEq(actualSettings.lastClaimedTimestamp, settings.lastClaimedTimestamp);
    assertEq(actualSettings.fundingExpiry, settings.fundingExpiry);
    assertEq(actualSettings.seasonStart, settings.seasonStart);
    assertEq(actualSettings.seasonDuration, settings.seasonDuration);
    assertEq(actualSettings.minVouches, settings.minVouches);
    assertEq(actualSettings.optimismFoundationAttesters[0], settings.optimismFoundationAttesters[0]);
  }

  function test_InitializeWhenPassingInvalidSettings() external {
    // Deploy implementation
    BuildersManager implementation = new BuildersManager();

    // Create invalid settings (zero cycle length)
    IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 0, // Invalid cycle length
      lastClaimedTimestamp: uint64(block.timestamp),
      fundingExpiry: uint64(304 days),
      seasonStart: uint64(1_704_067_200),
      seasonDuration: uint64(365 days),
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    settings.optimismFoundationAttesters[0] = address(this);

    // Expect revert when deploying proxy with invalid settings
    vm.expectRevert(IBuildersManager.SettingsNotSet.selector);
    new TransparentUpgradeableProxy(
      address(implementation),
      address(this),
      abi.encodeWithSelector(IBuildersManager.initialize.selector, token, eas, 'BuildersManager', '1', settings)
    );
  }

  function test_Initialize() public {
    // Attempt to reinitialize (should fail)
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    buildersManager.initialize(
      token,
      eas,
      'BuildersManager',
      '1',
      IBuildersManager.BuilderManagerSettings({
        cycleLength: 7 days,
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(304 days),
        seasonStart: uint64(1_704_067_200),
        seasonDuration: uint64(365 days),
        minVouches: 3,
        optimismFoundationAttesters: new address[](1)
      })
    );
  }
}
