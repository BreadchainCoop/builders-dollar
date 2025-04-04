// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BuilderDollar} from '@obs-usd-token/BuilderDollar.sol';
import {IBuilderManager} from 'contracts/BuilderManager.sol';

import {console} from 'forge-std/console.sol';
import {Common, DeploymentParams} from 'script/Common.sol';
import {OPTIMISM_CHAIN_ID, OP_SCHEMA_599, OP_SCHEMA_638, TEST_OP_BREAD_COOP} from 'script/Constants.sol';

/**
 * @notice These scripts are intended for testing on the Frontend.
 * @dev They are not used for Unit or Integration tests.
 */
contract SetUpForTest is Common {
  /// @notice Set to false to use test deployment parameters
  bool public constant PRODUCTION_ENV = false;

  function setUp() public virtual override {
    super.setUp();
    if (block.chainid == OPTIMISM_CHAIN_ID) initialOwner = TEST_OP_BREAD_COOP;
    else revert UnsupportedChain();
  }
}

/// @notice Remove OpenZeppelin `_disableInitializers` from BuilderManager and obUSD token before this script
contract DeployImplementationForTest is SetUpForTest {
  /**
   * @notice Deploy the BuilderManager and BuilderDollar implementations
   * @dev To verify implementations before deploying proxies
   */
  function run() public {
    DeploymentParams memory _s = _deploymentParams[block.chainid][PRODUCTION_ENV];

    vm.startBroadcast();
    obUsdToken = BuilderDollar(_deployBuilderDollarImp());
    obUsdToken.initialize(_s.admin, _s.underlyingAsset, _s.aToken, _s.aaveV3Pool, _s.tokenName, _s.tokenSymbol);
    builderManager = IBuilderManager(_deployBuilderManagerImp());
    builderManager.initialize(address(obUsdToken), _s.eas, _s.admin, _s.name, _s.version, _s.settings);
    builderManager.initializeSchemas(
      OP_SCHEMA_599, _deploySchemaValidator599(), OP_SCHEMA_638, _deploySchemaValidator638()
    );
    obUsdToken.initializeYieldClaimer(address(builderManager));
    vm.stopBroadcast();

    console.log('BuilderManager deployed', address(builderManager));
    console.log('BuilderDollar  deployed', address(obUsdToken));
    console.log('Initial  owner  set   to', initialOwner);
    console.log('Deployment complete');
  }
}

contract DeployProxyForTest is SetUpForTest {
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
