// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from '@oz/access/Ownable.sol';
import {Test} from 'forge-std/Test.sol';
import {Deploy} from 'script/Deploy.sol';

contract E2EDeploy is Deploy, Test {
  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);
    _deployContracts();
    vm.stopPrank();
  }

  function testDeployContracts() public view {
    assertNotEq(address(buildersManager), address(0));
    assertEq(Ownable(address(buildersManager)).owner(), deployer);
    assertNotEq(deployer, address(0));
  }
}
