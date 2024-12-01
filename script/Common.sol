// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';
import {Script} from 'forge-std/Script.sol';
// solhint-disable-next-line
import 'script/Registry.sol';

address constant EAS = address(0x420);
address constant BUILDERS_DOLLAR = address(0x421);

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
  IBuildersManager public builderManager;

  // @notice Deployer address will be the owner of the proxy
  address public deployer;

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _settings) internal _deploymentParams;

  function setUp() public virtual {
    // Optimism
    _deploymentParams[10] = DeploymentParams({
      token: BUILDERS_DOLLAR, // Replace with actual BuildersDollar address
      eas: EAS, // Replace with actual EAS address
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
  }

  function _deployContracts() internal {
    DeploymentParams memory _settings = _deploymentParams[block.chainid];

    address token = _settings.token;
    address eas = _settings.eas;
    string memory name = _settings.name;
    string memory version = _settings.version;
    IBuildersManager.BuilderManagerSettings memory settings = _settings.settings;

    address _implementation = address(new BuildersManager());
    builderManager = BuildersManager(
      address(
        new TransparentUpgradeableProxy(
          _implementation,
          deployer,
          abi.encodeWithSelector(IBuildersManager.initialize.selector, token, eas, name, version, settings)
        )
      )
    );
  }
}
