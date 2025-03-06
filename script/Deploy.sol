// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Common} from 'script/Common.sol';
import {ANVIL_CHAIN_ID, OPTIMISM_CHAIN_ID, SEPOLIA_CHAIN_ID} from 'script/Constants.sol';

contract Deploy is Common {
  uint256 public constant PUBLIC_ANVIL_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

  /**
   * @notice Set up the deployer address based on the chain ID
   * @dev The deployer address is the owner of the contracts
   */
  function setUp() public virtual override {
    super.setUp();
    uint256 _deployerPk;

    if (block.chainid == OPTIMISM_CHAIN_ID) _deployerPk = uint256(vm.envBytes32('OPTIMISM_DEPLOYER_PK'));
    else if (block.chainid == SEPOLIA_CHAIN_ID) _deployerPk = uint256(vm.envBytes32('SEPOLIA_DEPLOYER_PK'));
    else if (block.chainid == ANVIL_CHAIN_ID) _deployerPk = uint256(PUBLIC_ANVIL_PK);

    deployer = vm.addr(_deployerPk);
  }

  /**
   * @notice Deployment actions (see Common.sol for more details)
   * 1. Deploy Builders Dollar (OBSUSD) as a proxy
   * 2. Add OBSUSD to chain specific deployment params
   * 3. Deploy Builders Manager as a proxy
   */
  function run() public {
    vm.startBroadcast();
    _runDeployments();
    vm.stopBroadcast();
  }
}
