// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from 'forge-std/Test.sol';
import {Common} from 'script/Common.sol';
// solhint-disable-next-line
import 'script/Registry.sol';

contract IntegrationBase is Common, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = makeAddr('owner');

  function setUp() public virtual override {
    super.setUp();
    deployer = owner;
    vm.createSelectFork(vm.rpcUrl('gnosis'));

    vm.startPrank(owner);
    _deployContracts();
    vm.stopPrank();
  }
}
