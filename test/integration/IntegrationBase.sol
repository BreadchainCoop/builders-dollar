// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from 'forge-std/Test.sol';
import {Common} from 'script/Common.sol';
import {IBuildersManager} from 'src/interfaces/IBuildersManager.sol';

contract IntegrationBase is Common, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = makeAddr('owner');

  function setUp() public virtual override {
    super.setUp();
    deployer = owner;
    vm.createSelectFork(vm.rpcUrl('optimism'));

    vm.startPrank(owner);
    buildersManager = IBuildersManager(address(_deployBuildersManager()));
    vm.stopPrank();
  }
}
