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
  BUILDERS_MANAGER_NAME,
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
  OP_USDC,
  TEST_BUILDERS_MANAGER_NAME,
  TEST_OBSUSD_NAME,
  TEST_OBSUSD_SYMBOL,
  TEST_OP_CYCLE_LENGTH,
  TEST_OP_FUNDING_EXPIRY,
  TEST_OP_MIN_VOUCHES,
  TEST_OP_SEASON_DURATION,
  TEST_OP_SEASON_START
} from 'script/Constants.sol';

struct DeploymentParams {
  /// @dev BuildersManager settings
  address token; // BuildersDollar token address
  address eas; // Ethereum Attestation Service address
  address admin; // Admin address
  string name; // Contract name for EIP712
  string version; // Contract version for EIP712
  IBuildersManager.BuilderManagerSettings settings; // Settings struct
  /// @dev BuildersDollar settings
  address underlyingAsset; // Underlying asset address
  address aToken; // aToken address
  address aaveV3Pool; // Aave V3 pool address
  address aaveV3Incentives; // Aave V3 incentives address
  string tokenName; // Token name for OBSUSD
  string tokenSymbol; // Token symbol for OBSUSD
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
  mapping(uint256 _chainId => mapping(bool _isProoduction => DeploymentParams _settings)) internal _deploymentParams;

  function setUp() public virtual {
    // Optimism Deployment Params for Production Deployments and Integration Tests
    address[] memory _opAttesters = new address[](2);
    _opAttesters[0] = OP_FOUNDATION_ATTESTER_0;
    _opAttesters[1] = OP_FOUNDATION_ATTESTER_1;

    // Optimism Deployment Params for Production Deployments
    _deploymentParams[OPTIMISM_CHAIN_ID][true] = DeploymentParams({
      /// @dev BuildersManager settings
      token: address(obsUsdToken),
      eas: OP_EAS,
      name: BUILDERS_MANAGER_NAME,
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
      }),
      /// @dev BuildersDollar settings
      underlyingAsset: OP_USDC,
      aToken: OP_A_USDC,
      aaveV3Pool: OP_AAVE_V3_POOL,
      aaveV3Incentives: OP_AAVE_V3_INCENTIVES,
      tokenName: OBSUSD_NAME,
      tokenSymbol: OBSUSD_SYMBOL
    });

    // Optimism Deployment Params for Integration Tests
    _deploymentParams[OPTIMISM_CHAIN_ID][false] = DeploymentParams({
      /// @dev BuildersManager settings
      token: address(obsUsdToken),
      eas: OP_EAS,
      name: TEST_BUILDERS_MANAGER_NAME,
      admin: OP_BREAD_COOP,
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: uint64(TEST_OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(TEST_OP_FUNDING_EXPIRY),
        seasonStart: uint64(TEST_OP_SEASON_START),
        seasonDuration: uint64(TEST_OP_SEASON_DURATION),
        minVouches: TEST_OP_MIN_VOUCHES,
        optimismFoundationAttesters: _opAttesters
      }),
      /// @dev BuildersDollar settings
      underlyingAsset: OP_USDC,
      aToken: OP_A_USDC,
      aaveV3Pool: OP_AAVE_V3_POOL,
      aaveV3Incentives: OP_AAVE_V3_INCENTIVES,
      tokenName: TEST_OBSUSD_NAME,
      tokenSymbol: TEST_OBSUSD_SYMBOL
    });

    // Anvil Deployment Params for Unit Tests
    address[] memory _anvilAttesters = new address[](3);
    _anvilAttesters[0] = ANVIL_FOUNDATION_ATTESTER_0;
    _anvilAttesters[1] = ANVIL_FOUNDATION_ATTESTER_1;
    _anvilAttesters[2] = ANVIL_FOUNDATION_ATTESTER_2;

    _deploymentParams[ANVIL_CHAIN_ID][true] = DeploymentParams({
      /// @dev BuildersManager settings
      token: ANVIL_BUILDERS_DOLLAR,
      eas: ANVIL_EAS,
      admin: OP_BREAD_COOP,
      name: BUILDERS_MANAGER_NAME,
      version: '1',
      settings: IBuildersManager.BuilderManagerSettings({
        cycleLength: uint64(OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(OP_FUNDING_EXPIRY),
        seasonStart: uint64(OP_SEASON_START),
        seasonDuration: uint64(OP_SEASON_DURATION),
        minVouches: OP_MIN_VOUCHES,
        optimismFoundationAttesters: _anvilAttesters
      }),
      /// @dev BuildersDollar settings
      underlyingAsset: OP_USDC,
      aToken: OP_A_USDC,
      aaveV3Pool: OP_AAVE_V3_POOL,
      aaveV3Incentives: OP_AAVE_V3_INCENTIVES,
      tokenName: OBSUSD_NAME,
      tokenSymbol: OBSUSD_SYMBOL
    });
  }

  function _runDeployments(bool _isProduction) internal {
    obsUsdToken = BuildersDollar(_deployBuildersDollar(_isProduction));
    _deploymentParams[block.chainid][_isProduction].token = address(obsUsdToken);
    buildersManager = IBuildersManager(_deployBuildersManager(_isProduction));
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

  function _deployBuildersManager(bool _isProduction) internal returns (address _buildersManagerProxy) {
    address _implementation = _deployBuildersManagerImp();

    DeploymentParams memory _s = _deploymentParams[block.chainid][_isProduction];

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

  function _deployBuildersDollar(bool _isProduction) internal returns (address _obsUsdTokenProxy) {
    address _implementation = _deployBuildersDollarImp();

    DeploymentParams memory _s = _deploymentParams[block.chainid][_isProduction];

    _obsUsdTokenProxy = address(
      new EIP173ProxyWithReceive(
        _implementation,
        initialOwner,
        abi.encodeWithSelector(
          BuildersDollar.initialize.selector,
          _s.admin,
          _s.underlyingAsset,
          _s.aToken,
          _s.aaveV3Pool,
          _s.aaveV3Incentives,
          _s.tokenName,
          _s.tokenSymbol
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
