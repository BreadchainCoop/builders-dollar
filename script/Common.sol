// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BuildersDollar} from '@obs-usd-token/BuildersDollar.sol';
import {EIP173ProxyWithReceive} from '@obs-usd-token/vendor/EIP173ProxyWithReceive.sol';
import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';
import {Script} from 'forge-std/Script.sol';
import {
  ANVIL_BUILDERS_DOLLAR,
  ANVIL_CHAIN_ID,
  ANVIL_EAS,
  ANVIL_FOUNDATION_ATTESTER_0,
  ANVIL_FOUNDATION_ATTESTER_1,
  ANVIL_FOUNDATION_ATTESTER_2,
  OBSUSD_NAME,
  OBSUSD_SYMBOL,
  OPTIMISM_CHAIN_ID,
  OP_AAVE_V3_INCENTIVES,
  OP_AAVE_V3_POOL,
  OP_A_DAI,
  OP_DAI,
  OP_EAS,
  OP_FOUNDATION_ATTESTER_0
} from 'script/Constants.sol';

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
  /// @notice BuildersManager contract
  IBuildersManager public buildersManager;
  /// @notice BuildersDollar contract
  BuildersDollar public obsUsdToken;

  /// @notice Deployer address will be the owner of the proxy
  address public deployer;

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _settings) internal _deploymentParams;

  function setUp() public virtual {
    // Optimism Deployment Params
    address[] memory _opAttesters = new address[](1);
    _opAttesters[0] = OP_FOUNDATION_ATTESTER_0;

    _deploymentParams[OPTIMISM_CHAIN_ID] = DeploymentParams({
      token: address(obsUsdToken),
      eas: OP_EAS,
      name: 'BuildersManager',
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: 7 days,
        lastClaimedTimestamp: uint64(block.timestamp),
        currentSeasonExpiry: uint64(block.timestamp + 180 days),
        seasonDuration: 365 days,
        minVouches: 3,
        optimismFoundationAttesters: _opAttesters
      })
    });

    // Anvil Deployment Params
    address[] memory _anvilAttesters = new address[](3);
    _anvilAttesters[0] = ANVIL_FOUNDATION_ATTESTER_0;
    _anvilAttesters[1] = ANVIL_FOUNDATION_ATTESTER_1;
    _anvilAttesters[2] = ANVIL_FOUNDATION_ATTESTER_2;

    _deploymentParams[ANVIL_CHAIN_ID] = DeploymentParams({
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
        optimismFoundationAttesters: _anvilAttesters
      })
    });
  }

  function _runDeployments() internal {
    obsUsdToken = BuildersDollar(_deployBuildersDollar());
    _deploymentParams[block.chainid].token = address(obsUsdToken);
    buildersManager = IBuildersManager(_deployBuildersManager());
  }

  function _deployBuildersManager() internal returns (address _buildersManagerProxy) {
    address _implementation = address(new BuildersManager());

    DeploymentParams memory _s = _deploymentParams[block.chainid];

    _buildersManagerProxy = address(
      new TransparentUpgradeableProxy(
        _implementation,
        deployer,
        abi.encodeWithSelector(IBuildersManager.initialize.selector, _s.token, _s.eas, _s.name, _s.version, _s.settings)
      )
    );
  }

  function _deployBuildersDollar() internal returns (address _obsUsdTokenProxy) {
    address _implementation = address(new BuildersDollar(OP_DAI, OP_A_DAI, OP_AAVE_V3_POOL, OP_AAVE_V3_INCENTIVES));

    _obsUsdTokenProxy = address(
      new EIP173ProxyWithReceive(
        _implementation,
        deployer,
        abi.encodeWithSelector(BuildersDollar.initialize.selector, OBSUSD_NAME, OBSUSD_SYMBOL)
      )
    );
  }
}
