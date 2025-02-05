// SPDX-License-Identifier: PPL
pragma solidity 0.8.27;

import {Ownable} from '@oz/access/Ownable.sol';
import {Test} from 'forge-std/Test.sol';
import {Deploy} from 'script/Deploy.sol';

contract IntegrationDeploy is Deploy, Test {
  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);
    buildersManager = _deployBuildersManager();
    vm.stopPrank();
  }

  function test_DeployContracts() public view {
    assertNotEq(address(buildersManager), address(0));
    assertEq(Ownable(address(buildersManager)).owner(), deployer);
    assertNotEq(deployer, address(0));
  }
}
