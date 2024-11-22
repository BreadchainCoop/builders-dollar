// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Common} from 'script/Common.sol';

contract Deploy is Common {
  function run() public {
    vm.startBroadcast();

    _deployContracts();

    vm.stopBroadcast();
  }
}
