// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Test} from 'forge-std/Test.sol';
import {Common} from 'script/Common.sol';
// solhint-disable-next-line
import 'script/Registry.sol';

contract IntegrationBase is Common, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = makeAddr('owner');

  IERC20 public bread = IERC20(GNOSIS_BREAD);

  function setUp() public virtual override {
    super.setUp();
    vm.createSelectFork(vm.rpcUrl('gnosis'));
    vm.startPrank(owner);

    /// @dev deploy contracts methods are located in script/Common.sol
    _deployContracts();

    vm.stopPrank();
    deal(GNOSIS_BREAD, address(greeter), INIT_BALANCE);
  }
}
