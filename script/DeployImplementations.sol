// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Common} from 'script/Common.sol';

contract DeployImplementations is Common {
  /**
   * @notice Deploy the BuilderManager and BuilderDollar implementations
   * @dev To verify implementations before deploying proxies
   */
  function run() public {
    vm.startBroadcast();
    _deployBuildersManagerImp();
    _deployBuildersDollarImp();
    vm.stopBroadcast();
  }
}
