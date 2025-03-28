// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BuildersDollar} from '@obs-usd-token/BuildersDollar.sol';
import {EIP173ProxyWithReceive} from '@obs-usd-token/vendor/EIP173ProxyWithReceive.sol';
import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';
import {SchemaValidator599} from 'contracts/schemas/SchemaValidator599.sol';
import {SchemaValidator638} from 'contracts/schemas/SchemaValidator638.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
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
  OP_A_USDC,
  OP_BREAD_COOP,
  OP_CYCLE_LENGTH,
  OP_EAS,
  OP_FOUNDATION_ATTESTER_0,
  OP_FOUNDATION_ATTESTER_1,
  OP_FUNDING_EXPIRY,
  OP_MIN_VOUCHES,
  OP_SCHEMA_599,
  OP_SCHEMA_638,
  OP_SEASON_DURATION,
  OP_SEASON_START,
  OP_USDC
} from 'script/Constants.sol';

struct DeploymentParams {
  address token; // BuildersDollar token address
  address eas; // Ethereum Attestation Service address
  address admin; // Admin address
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

  /// @notice initialOwner address will be the owner of the proxy
  address public initialOwner;

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _settings) internal _deploymentParams;

  function setUp() public virtual {
    // Optimism Deployment Params
    address[] memory _opAttesters = new address[](2);
    _opAttesters[0] = OP_FOUNDATION_ATTESTER_0;
    _opAttesters[1] = OP_FOUNDATION_ATTESTER_1;

    _deploymentParams[OPTIMISM_CHAIN_ID] = DeploymentParams({
      token: address(obsUsdToken),
      eas: OP_EAS,
      name: 'BuildersManager',
      admin: OP_BREAD_COOP,
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: uint64(OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(OP_FUNDING_EXPIRY),
        seasonStart: uint64(OP_SEASON_START),
        seasonDuration: uint64(OP_SEASON_DURATION),
        minVouches: OP_MIN_VOUCHES,
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
      admin: OP_BREAD_COOP,
      name: 'BuildersManager',
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: uint64(OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(OP_FUNDING_EXPIRY),
        seasonStart: uint64(OP_SEASON_START),
        seasonDuration: uint64(OP_SEASON_DURATION),
        minVouches: OP_MIN_VOUCHES,
        optimismFoundationAttesters: _anvilAttesters
      })
    });
  }

  function _runDeployments() internal {
    obsUsdToken = BuildersDollar(_deployBuildersDollar());
    _deploymentParams[block.chainid].token = address(obsUsdToken);
    buildersManager = IBuildersManager(_deployBuildersManager());
    buildersManager.initializeSchemas(
      OP_SCHEMA_599, address(_deploySchemaValidator599()), OP_SCHEMA_638, address(_deploySchemaValidator638())
    );
    obsUsdToken.initializeYieldClaimer(address(buildersManager));

    console.log('BuildersManager deployed', address(buildersManager));
    console.log('BuildersDollar  deployed', address(obsUsdToken));
    console.log('Initial  owner  set   to', initialOwner);
    console.log('Deployment complete');
  }

  function _deployBuildersManagerImp() internal returns (address _buildersManagerImp) {
    _buildersManagerImp = address(new BuildersManager());
  }

  function _deployBuildersManager() internal returns (address _buildersManagerProxy) {
    address _implementation = _deployBuildersManagerImp();

    DeploymentParams memory _s = _deploymentParams[block.chainid];

    _buildersManagerProxy = address(
      new TransparentUpgradeableProxy(
        _implementation,
        initialOwner,
        abi.encodeWithSelector(
          IBuildersManager.initialize.selector, _s.token, _s.eas, _s.admin, _s.name, _s.version, _s.settings
        )
      )
    );
  }

  function _deployBuildersDollarImp() internal returns (address _obsUsdTokenImp) {
    _obsUsdTokenImp = address(new BuildersDollar());
  }

  function _deployBuildersDollar() internal returns (address _obsUsdTokenProxy) {
    address _implementation = _deployBuildersDollarImp();

    _obsUsdTokenProxy = address(
      new EIP173ProxyWithReceive(
        _implementation,
        initialOwner,
        abi.encodeWithSelector(
          BuildersDollar.initialize.selector,
          OP_BREAD_COOP,
          OP_USDC,
          OP_A_USDC,
          OP_AAVE_V3_POOL,
          OP_AAVE_V3_INCENTIVES,
          OBSUSD_NAME,
          OBSUSD_SYMBOL
        )
      )
    );
  }

  function _deploySchemaValidator599() internal returns (address _schemaValidatorProxy) {
    _schemaValidatorProxy = address(new SchemaValidator599(OP_SCHEMA_599, address(buildersManager)));
  }

  function _deploySchemaValidator638() internal returns (address _schemaValidatorProxy) {
    _schemaValidatorProxy = address(new SchemaValidator638(OP_SCHEMA_638, address(buildersManager)));
  }
}
