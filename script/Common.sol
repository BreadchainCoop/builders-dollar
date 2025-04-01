// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BuilderDollar} from '@obs-usd-token/BuilderDollar.sol';
import {EIP173ProxyWithReceive} from '@obs-usd-token/vendor/EIP173ProxyWithReceive.sol';
import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuilderManager, IBuilderManager} from 'contracts/BuilderManager.sol';
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
  TEST_OP_CYCLE_LENGTH,
  TEST_OP_FUNDING_EXPIRY,
  TEST_OP_MIN_VOUCHES,
  TEST_OP_SEASON_DURATION,
  TEST_OP_SEASON_START,
  TEST_obUSD_NAME,
  TEST_obUSD_SYMBOL,
  obUSD_NAME,
  obUSD_SYMBOL
} from 'script/Constants.sol';

struct DeploymentParams {
  /// @dev BuilderManager settings
  address token; // BuilderDollar token address
  address eas; // Ethereum Attestation Service address
  address admin; // Admin address
  string name; // Contract name for EIP712
  string version; // Contract version for EIP712
  IBuilderManager.BuilderManagerSettings settings; // Settings struct
  /// @dev BuilderDollar settings
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
 * @notice This contract is used to deploy the BuilderManager contract
 * @dev This contract is intended for use in Scripts and Integration Tests
 */
contract Common is Script {
  /// @notice BuilderManager contract
  IBuilderManager public builderManager;
  /// @notice BuilderDollar contract
  BuilderDollar public obUsdToken;

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
      /// @dev BuilderManager settings
      token: address(obUsdToken),
      eas: OP_EAS,
      name: BUILDERS_MANAGER_NAME,
      admin: OP_BREAD_COOP,
      version: '1',
      settings: IBuilderManager.BuilderManagerSettings({
        cycleLength: uint64(OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(OP_FUNDING_EXPIRY),
        seasonStart: uint64(OP_SEASON_START),
        seasonDuration: uint64(OP_SEASON_DURATION),
        minVouches: OP_MIN_VOUCHES,
        optimismFoundationAttesters: _opAttesters
      }),
      /// @dev BuilderDollar settings
      underlyingAsset: OP_USDC,
      aToken: OP_A_USDC,
      aaveV3Pool: OP_AAVE_V3_POOL,
      aaveV3Incentives: OP_AAVE_V3_INCENTIVES,
      tokenName: obUSD_NAME,
      tokenSymbol: obUSD_SYMBOL
    });

    // Optimism Deployment Params for Integration Tests
    _deploymentParams[OPTIMISM_CHAIN_ID][false] = DeploymentParams({
      /// @dev BuilderManager settings
      token: address(obUsdToken),
      eas: OP_EAS,
      name: TEST_BUILDERS_MANAGER_NAME,
      admin: OP_BREAD_COOP,
      version: '1',
      settings: IBuilderManager.BuilderManagerSettings({
        cycleLength: uint64(TEST_OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(TEST_OP_FUNDING_EXPIRY),
        seasonStart: uint64(TEST_OP_SEASON_START),
        seasonDuration: uint64(TEST_OP_SEASON_DURATION),
        minVouches: TEST_OP_MIN_VOUCHES,
        optimismFoundationAttesters: _opAttesters
      }),
      /// @dev BuilderDollar settings
      underlyingAsset: OP_USDC,
      aToken: OP_A_USDC,
      aaveV3Pool: OP_AAVE_V3_POOL,
      aaveV3Incentives: OP_AAVE_V3_INCENTIVES,
      tokenName: TEST_obUSD_NAME,
      tokenSymbol: TEST_obUSD_SYMBOL
    });

    // Anvil Deployment Params for Unit Tests
    address[] memory _anvilAttesters = new address[](3);
    _anvilAttesters[0] = ANVIL_FOUNDATION_ATTESTER_0;
    _anvilAttesters[1] = ANVIL_FOUNDATION_ATTESTER_1;
    _anvilAttesters[2] = ANVIL_FOUNDATION_ATTESTER_2;

    _deploymentParams[ANVIL_CHAIN_ID][true] = DeploymentParams({
      /// @dev BuilderManager settings
      token: ANVIL_BUILDERS_DOLLAR,
      eas: ANVIL_EAS,
      admin: OP_BREAD_COOP,
      name: BUILDERS_MANAGER_NAME,
      version: '1',
      settings: IBuilderManager.BuilderManagerSettings({
        cycleLength: uint64(OP_CYCLE_LENGTH),
        lastClaimedTimestamp: uint64(block.timestamp),
        fundingExpiry: uint64(OP_FUNDING_EXPIRY),
        seasonStart: uint64(OP_SEASON_START),
        seasonDuration: uint64(OP_SEASON_DURATION),
        minVouches: OP_MIN_VOUCHES,
        optimismFoundationAttesters: _anvilAttesters
      }),
      /// @dev BuilderDollar settings
      underlyingAsset: OP_USDC,
      aToken: OP_A_USDC,
      aaveV3Pool: OP_AAVE_V3_POOL,
      aaveV3Incentives: OP_AAVE_V3_INCENTIVES,
      tokenName: obUSD_NAME,
      tokenSymbol: obUSD_SYMBOL
    });
  }

  function _runDeployments(bool _isProduction) internal {
    obUsdToken = BuilderDollar(_deployBuildersDollar(_isProduction));
    _deploymentParams[block.chainid][_isProduction].token = address(obUsdToken);
    builderManager = IBuilderManager(_deployBuildersManager(_isProduction));
    builderManager.initializeSchemas(
      OP_SCHEMA_599, address(_deploySchemaValidator599()), OP_SCHEMA_638, address(_deploySchemaValidator638())
    );
    obUsdToken.initializeYieldClaimer(address(builderManager));

    console.log('BuilderManager deployed', address(builderManager));
    console.log('BuilderDollar  deployed', address(obUsdToken));
    console.log('Initial  owner  set   to', initialOwner);
    console.log('Deployment complete');
  }

  function _deployBuildersManagerImp() internal returns (address _buildersManagerImp) {
    _buildersManagerImp = address(new BuilderManager());
  }

  function _deployBuildersManager(bool _isProduction) internal returns (address _buildersManagerProxy) {
    address _implementation = _deployBuildersManagerImp();

    DeploymentParams memory _s = _deploymentParams[block.chainid][_isProduction];

    _buildersManagerProxy = address(
      new TransparentUpgradeableProxy(
        _implementation,
        initialOwner,
        abi.encodeWithSelector(
          IBuilderManager.initialize.selector, _s.token, _s.eas, _s.admin, _s.name, _s.version, _s.settings
        )
      )
    );
  }

  function _deployBuildersDollarImp() internal returns (address _obUsdTokenImp) {
    _obUsdTokenImp = address(new BuilderDollar());
  }

  function _deployBuildersDollar(bool _isProduction) internal returns (address _obUsdTokenProxy) {
    address _implementation = _deployBuildersDollarImp();

    DeploymentParams memory _s = _deploymentParams[block.chainid][_isProduction];

    _obUsdTokenProxy = address(
      new EIP173ProxyWithReceive(
        _implementation,
        initialOwner,
        abi.encodeWithSelector(
          BuilderDollar.initialize.selector,
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
    _schemaValidatorProxy = address(new SchemaValidator599(OP_SCHEMA_599, address(builderManager)));
  }

  function _deploySchemaValidator638() internal returns (address _schemaValidatorProxy) {
    _schemaValidatorProxy = address(new SchemaValidator638(OP_SCHEMA_638, address(builderManager)));
  }
}
