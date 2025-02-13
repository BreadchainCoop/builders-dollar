// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from 'forge-std/Test.sol';
import {Deploy} from 'script/Deploy.sol';

contract IntegrationBase is Deploy, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = makeAddr('owner');

  function setUp() public virtual override {
    super.setUp();
    deployer = owner;
    vm.createSelectFork(vm.rpcUrl('optimism'));

    vm.startPrank(owner);
    _runDeployments();
    vm.stopPrank();
  }
}
