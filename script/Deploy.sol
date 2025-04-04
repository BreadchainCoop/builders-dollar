// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Common} from 'script/Common.sol';
import {ANVIL_CHAIN_ID, OPTIMISM_CHAIN_ID, OP_BREAD_COOP} from 'script/Constants.sol';

contract Deploy is Common {
  uint256 public constant PUBLIC_ANVIL_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  bool public constant PRODUCTION_ENV = true;

  /**
   * @notice Set up the initialOwner address based on the chain ID
   */
  function setUp() public virtual override {
    super.setUp();
    if (block.chainid == OPTIMISM_CHAIN_ID) initialOwner = OP_BREAD_COOP;
    else if (block.chainid == ANVIL_CHAIN_ID) initialOwner = address(vm.addr(PUBLIC_ANVIL_PK));
    else revert UnsupportedChain();
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
