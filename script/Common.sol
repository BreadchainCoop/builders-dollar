// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';
import {Script} from 'forge-std/Script.sol';
// solhint-disable-next-line
import 'script/Registry.sol';

struct DeploymentParams {
  address token; // BuildersDollar token address
  address eas; // Ethereum Attestation Service address
  string name; // Contract name for EIP712
  string version; // Contract version for EIP712
  IBuildersManager.BuilderManagerSettings settings; // Settings struct
}

/**
 * @title Common Contract
 * @author Breadchain
 * @notice This contract is used to deploy the BuildersManager contract
 * @dev This contract is intended for use in Scripts and Integration Tests
 */
contract Common is Script {
  IBuildersManager public buildersManager;

  // @notice Deployer address will be the owner of the proxy
  address public deployer;

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _settings) internal _deploymentParams;

  function setUp() public virtual {
    // Optimism
    _deploymentParams[10] = DeploymentParams({
      token: OP_BUILDERS_DOLLAR, // Replace with actual BuildersDollar address
      eas: OP_EAS, // Replace with actual EAS address
      name: 'BuildersManager',
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: 7 days,
        lastClaimedTimestamp: uint64(block.timestamp),
        currentSeasonExpiry: uint64(block.timestamp + 180 days),
        seasonDuration: 365 days,
        minVouches: 3,
        optimismFoundationAttesters: new address[](0) // Replace with actual attesters
      })
    });

    // Anvil
    address[] memory _attesters = new address[](3);
    _attesters[0] = ANVIL_FOUNDATION_ATTESTER_1;
    _attesters[1] = ANVIL_FOUNDATION_ATTESTER_2;
    _attesters[2] = ANVIL_FOUNDATION_ATTESTER_3;

    _deploymentParams[31_337] = DeploymentParams({
      token: ANVIL_BUILDERS_DOLLAR,
      eas: ANVIL_EAS,
      name: 'BuildersManager',
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: 7 days,
        lastClaimedTimestamp: uint64(block.timestamp),
        currentSeasonExpiry: uint64(block.timestamp + 180 days),
        seasonDuration: 365 days,
        minVouches: 3,
        optimismFoundationAttesters: _attesters
      })
    });
  }

  function _deployContracts() internal {
    DeploymentParams memory _s = _deploymentParams[block.chainid];

    address _implementation = address(new BuildersManager());
    buildersManager = BuildersManager(
      address(
        new TransparentUpgradeableProxy(
          _implementation,
          deployer,
          abi.encodeWithSelector(
            IBuildersManager.initialize.selector, _s.token, _s.eas, _s.name, _s.version, _s.settings
          )
        )
      )
    );
  }
}
