// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IEAS} from '@eas/IEAS.sol';
import {Test} from 'forge-std/Test.sol';
import {Deploy} from 'script/Deploy.sol';

contract IntegrationBase is Deploy, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = makeAddr('owner');

  /// @notice EAS contract
  IEAS public eas;

  /// @notice Schema #638 attestation
  struct Schema638Attestation {
    bytes32 projectRefId;
    string userIncentiveOP;
    string buildersOP;
    string season;
    string intent;
    string mission;
    string approvalDate;
    string metaUrl;
  }

  function setUp() public virtual override {
    super.setUp();
    deployer = owner;
    vm.createSelectFork(vm.rpcUrl('optimism'));

    vm.startPrank(owner);
    _runDeployments();
    vm.stopPrank();

    eas = buildersManager.EAS();

    vm.label(address(buildersManager), 'BUILDERS_MANAGER');
    vm.label(address(obsUsdToken), 'OBS_USD_TOKEN');
    vm.label(address(eas), 'EAS');
    vm.label(owner, 'OWNER');
  }
}
