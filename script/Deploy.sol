// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {EIP173ProxyWithReceive} from '@obs-usd-token/vendor/EIP173ProxyWithReceive.sol';
import {Common} from 'script/Common.sol';

contract Deploy is Common {
  function setUp() public virtual override {
    super.setUp();

    uint256 _deployerPk = uint256(vm.envBytes32('OPTIMISM_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);
  }

  /**
   * @notice Deployment actions
   * 1. Deploy Builders Dollar (OBSUSD) as a proxy
   * 2. Add OBSUSD to chain specific deployment params
   * 3. Deploy Builders Manager as a proxy
   */
  function run() public {
    vm.startBroadcast();
    (, EIP173ProxyWithReceive _obsUsdTokenProxy) = _deployBuildersDollar();
    _deploymentParams[block.chainid].token = address(_obsUsdTokenProxy);
    _deployBuildersManager();
    vm.stopBroadcast();
  }
}
