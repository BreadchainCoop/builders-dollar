// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Common} from 'script/Common.sol';
import {OPTIMISM_CHAIN_ID, OP_BREAD_COOP} from 'script/Constants.sol';

contract DeployWithTestParams is Common {
  bool public constant PRODUCTION_ENV = false;

  /**
   * @notice Set up the initialOwner address based on the chain ID
   */
  function setUp() public virtual override {
    super.setUp();
    // todo: set to tester address
    if (block.chainid == OPTIMISM_CHAIN_ID) initialOwner = OP_BREAD_COOP;
  }

  /**
   * @notice Deployment actions (see Common.sol for more details)
   * 1. Deploy Builders Dollar (OBSUSD) as a proxy
   * 2. Add OBSUSD to chain specific deployment params
   * 3. Deploy Builders Manager as a proxy
   */
  function run() public {
    vm.startBroadcast();
    _runDeployments(PRODUCTION_ENV);
    vm.stopBroadcast();
  }
}
