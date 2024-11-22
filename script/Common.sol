// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Greeter, IGreeter} from 'contracts/Greeter.sol';
import {Script} from 'forge-std/Script.sol';
// solhint-disable-next-line
import 'script/Registry.sol';

/**
 * @title Common Contract
 * @author Breadchain
 * @notice This contract is used to deploy the Greeter contract
 * @dev This contract is intended for use in Scripts and Integration Tests
 */
contract Common is Script {
  struct DeploymentParams {
    string greeting;
    IERC20 token;
  }

  IGreeter public greeter;

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  function setUp() public virtual {
    // Optimism
    _deploymentParams[10] = DeploymentParams('Hello, Optimism!', IERC20(OPTIMISM_DAI));

    // Gnosis
    _deploymentParams[100] = DeploymentParams('Hello, Gnosis!', IERC20(GNOSIS_BREAD));
  }

  function _deployContracts() internal {
    DeploymentParams memory _params = _deploymentParams[block.chainid];

    greeter = new Greeter(_params.greeting, _params.token);
  }
}
