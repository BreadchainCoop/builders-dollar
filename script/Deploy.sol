// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Common} from 'script/Common.sol';

contract Deploy is Common {
  function run() public {
    uint256 _deployerPk = uint256(vm.envBytes32('OPTIMISM_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);

    vm.startBroadcast();
    _deployContracts();
    vm.stopBroadcast();
  }
}
