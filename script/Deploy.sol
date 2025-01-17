// SPDX-License-Identifier: PPL
pragma solidity 0.8.23;

import {Common} from 'script/Common.sol';

contract Deploy is Common {
  function setUp() public virtual override {
    super.setUp();

    uint256 _deployerPk = uint256(vm.envBytes32('OPTIMISM_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);
  }

  function run() public {
    vm.startBroadcast();
    _deployBuildersManager();
    vm.stopBroadcast();
  }
}
