// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IEAS} from '@eas/IEAS.sol';
import {Test} from 'forge-std/Test.sol';

import {OP_BREAD_COOP} from 'script/Constants.sol';
import {Deploy} from 'script/Deploy.sol';

contract IntegrationBase is Deploy, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = OP_BREAD_COOP;

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
    initialOwner = owner;
    vm.createSelectFork(vm.rpcUrl('optimism'));

    vm.startPrank(owner);
    /// @dev Fork test with production settings
    _runDeployments(PRODUCTION_ENV);
    vm.stopPrank();

    eas = builderManager.EAS();

    vm.label(address(builderManager), 'BUILDERS_MANAGER');
    vm.label(address(obUsdToken), 'OBS_USD_TOKEN');
    vm.label(address(eas), 'EAS');
    vm.label(owner, 'OWNER');
  }
}
