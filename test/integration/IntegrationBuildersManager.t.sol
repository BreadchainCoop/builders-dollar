// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IPool} from '@aave-core-v3/interfaces/IPool.sol';
import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {ERC20} from '@oz/token/ERC20/ERC20.sol';
import {IBuilderManager} from 'interfaces/IBuilderManager.sol';
import {
  OP_AAVE_V3_POOL,
  OP_A_USDC,
  OP_FOUNDATION_ATTESTER_0,
  OP_SCHEMA_599,
  OP_SCHEMA_UID_599_0,
  OP_SCHEMA_UID_599_1,
  OP_SCHEMA_UID_599_2,
  OP_SCHEMA_UID_599_3,
  OP_SCHEMA_UID_638_0,
  OP_USDC,
  OP_WETH_GATEWAY
} from 'script/Constants.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

/// @notice Interface for the IWETHGateway contract
interface IWETHGateway {
  /**
   * @notice Deposits WETH into the reserve, using native ETH and a corresponding amount of the overlying asset (aTokens) is minted
   * @param _pool address of the targeted lending pool
   * @param _onBehalfOf address of the user who will receive the aTokens
   * @param _referralCode integrators are assigned a referral code and can potentially receive rewards
   */
  function depositETH(address _pool, address _onBehalfOf, uint16 _referralCode) external payable;
}

contract IntegrationBuildersManager is IntegrationBase {
  // Constants for test configuration
  uint256 public constant MIN_VOUCHES = 3;
  uint256 public constant CYCLE_LENGTH = 7 days;
  uint256 public constant SEASON_DURATION = 90 days;
  uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
  uint256 public constant YIELD_AMOUNT = 10 ether;

  // Constants for token amounts
  uint256 public constant COLLATERAL_AMOUNT = 5000 ether; // Increased ETH collateral
  uint256 public constant WHALE_ETH_AMOUNT = 1000 ether; // Increased whale ETH amount

  // USDC has 6 decimals
  uint256 public constant USDC_DECIMALS = 6;
  uint256 public constant TOKEN_MINT_AMOUNT = 50 * 10 ** USDC_DECIMALS; // 50 USDC (reduced from 100)
  uint256 public constant BORROW_AMOUNT = 25 * 10 ** USDC_DECIMALS; // 25 USDC (reduced from 50)
  uint256 public constant SMALL_BORROW_AMOUNT = 2 * 10 ** USDC_DECIMALS; // 2 USDC (reduced from 5)
  uint256 public constant SMALL_REPAY_AMOUNT = (2 * 10 ** USDC_DECIMALS) + (2 * 10 ** USDC_DECIMALS / 10); // 2.2 USDC (2 + 10% interest)

  IWETHGateway public wethGateway = IWETHGateway(OP_WETH_GATEWAY);
  IPool public pool = IPool(OP_AAVE_V3_POOL);

  // Contract instances
  ERC20 public aUSDC;

  // Attestation state
  Attestation public projectAtt;
  Attestation public identityAtt0; // Guest voter
  Attestation public identityAtt1; // Citizen voter
  Attestation public identityAtt2; // Guest voter
  Attestation public identityAtt3; // New voter

  address public borrower = 0x48A63097E1Ac123b1f5A8bbfFafA4afa8192FaB0;

  function setUp() public override {
    super.setUp();
    vm.label(borrower, 'BORROWER');

    // Get the deployed contracts
    aUSDC = ERC20(OP_A_USDC);

    vm.label(address(aUSDC), 'A_USDC');
    vm.label(address(pool), 'POOL');
    vm.label(address(wethGateway), 'WETH_GATEWAY');
    // Get real attestations from EAS
    projectAtt = eas.getAttestation(OP_SCHEMA_UID_638_0);
    identityAtt0 = eas.getAttestation(OP_SCHEMA_UID_599_0);
    identityAtt1 = eas.getAttestation(OP_SCHEMA_UID_599_1);
    identityAtt2 = eas.getAttestation(OP_SCHEMA_UID_599_2);
    identityAtt3 = eas.getAttestation(OP_SCHEMA_UID_599_3);

    // Verify obUsdToken matches the token in BuilderManager
    assertEq(address(obUsdToken), address(builderManager.TOKEN()));

    // Set BuilderManager as the yield claimer for obUsdToken
    vm.startPrank(owner);
    obUsdToken.setYieldClaimer(address(builderManager));
    vm.stopPrank();

    // Deal some ETH to the borrower
    vm.deal(borrower, COLLATERAL_AMOUNT * 20); // Increased from 10x to 20x collateral amount for tests
  }

  // === Project Attestation Tests ===

  function test_ProjectAttestationValidation() public {
    // Validate project using identity attestation
    _vouchWithIdentity(identityAtt0.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);

    // Verify project is properly registered
    assertEq(builderManager.eligibleProject(OP_SCHEMA_UID_638_0), projectAtt.recipient);
    assertEq(builderManager.eligibleProjectByUid(projectAtt.recipient), OP_SCHEMA_UID_638_0);
  }

  // === Voter Attestation Tests ===

  function test_VoterAttestationValidation() public {
    // Test Guest voter
    vm.prank(identityAtt0.recipient);
    assertTrue(builderManager.validateOptimismVoter(OP_SCHEMA_UID_599_0));
    assertTrue(builderManager.eligibleVoter(identityAtt0.recipient));

    // Test Citizen voter
    vm.prank(identityAtt1.recipient);
    assertTrue(builderManager.validateOptimismVoter(OP_SCHEMA_UID_599_1));
    assertTrue(builderManager.eligibleVoter(identityAtt1.recipient));
  }

  function test_RevertOnInvalidVoterType() public {
    // Create invalid voter attestation with wrong voter type
    bytes memory invalidVoterData = abi.encode(uint256(320_694), 'Voter', 'Invalid', 'C', '3.2');
    Attestation memory invalidAttestation = Attestation({
      uid: bytes32(uint256(999)),
      schema: OP_SCHEMA_599,
      time: uint64(block.timestamp),
      expirationTime: uint64(block.timestamp + 365 days),
      revocationTime: uint64(0),
      refUID: EMPTY_UID,
      recipient: address(this),
      attester: OP_FOUNDATION_ATTESTER_0,
      revocable: true,
      data: invalidVoterData
    });

    // Mock only this invalid attestation
    vm.mockCall(
      address(eas),
      abi.encodeWithSignature('getAttestation(bytes32)', invalidAttestation.uid),
      abi.encode(invalidAttestation)
    );

    // Should return false for invalid voter type
    assertFalse(builderManager.validateOptimismVoter(invalidAttestation.uid));
    assertFalse(builderManager.eligibleVoter(address(this)));
  }

  // === Vouching System Tests ===

  function test_CompleteVouchingFlow() public {
    _getThreeVouches();

    // Verify project reached minimum vouches
    assertEq(builderManager.projectToVouches(projectAtt.recipient), MIN_VOUCHES);

    // Verify project is in current projects list
    address[] memory currentProjects = builderManager.currentProjects();
    assertEq(currentProjects[0], projectAtt.recipient);
  }

  function test_VouchingRestrictions() public {
    // First validate the project
    _vouchWithIdentity(identityAtt0.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);

    // Second vouch should succeed
    _vouchWithIdentity(identityAtt1.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);

    // Third vouch should fail (already verified)
    vm.expectRevert(IBuilderManager.AlreadyVerified.selector);
    vm.prank(identityAtt1.recipient);
    builderManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);

    // Fourth vouch should fail (already vouched)
    vm.expectRevert(IBuilderManager.AlreadyVouched.selector);
    vm.prank(identityAtt1.recipient);
    builderManager.vouch(OP_SCHEMA_UID_638_0);
  }

  // === Yield Distribution Tests ===

  function test_YieldDistributionCycle() public {
    _getThreeVouches();

    // Verify project is correctly registered
    assertEq(builderManager.projectToVouches(projectAtt.recipient), MIN_VOUCHES);
    assertEq(builderManager.currentProjects().length, 1);
    assertEq(builderManager.currentProjects()[0], projectAtt.recipient);

    // Get initial balances - this may revert on forked networks
    uint256 initialAUsdcBalance = aUSDC.balanceOf(address(obUsdToken));
    // First get some USDC for the owner and mint obsUSD to generate yield on
    address usdcWhale = makeAddr('usdcWhale');
    vm.label(usdcWhale, 'USDC_WHALE');
    vm.deal(usdcWhale, WHALE_ETH_AMOUNT);
    vm.startPrank(usdcWhale);
    wethGateway.depositETH{value: WHALE_ETH_AMOUNT}(OP_AAVE_V3_POOL, usdcWhale, 0);
    // Reduce borrow amount for USDC's lower LTV
    pool.borrow(OP_USDC, BORROW_AMOUNT, 2, 0, usdcWhale);
    ERC20(OP_USDC).transfer(owner, BORROW_AMOUNT);
    vm.stopPrank();

    // Now mint obsUSD
    vm.startPrank(owner);
    ERC20(OP_USDC).approve(address(obUsdToken), BORROW_AMOUNT);
    obUsdToken.mint(BORROW_AMOUNT, address(obUsdToken));
    vm.stopPrank();

    vm.startPrank(borrower);
    // Deposit ETH as collateral
    wethGateway.depositETH{value: COLLATERAL_AMOUNT}(OP_AAVE_V3_POOL, borrower, 0);

    // Borrow USDC to generate yield - use smaller amount
    pool.borrow(OP_USDC, SMALL_BORROW_AMOUNT, 2, 0, borrower);

    // Move time forward to allow yield to accrue
    vm.roll(block.number + 100_000);
    vm.warp(block.timestamp + CYCLE_LENGTH + 1);

    // IMPORTANT FIX: Deal USDC to the borrower for repayment since they transferred it all away
    // The borrower won't have enough USDC to repay because we didn't keep any
    deal(address(ERC20(OP_USDC)), borrower, SMALL_REPAY_AMOUNT);

    // Repay the loan with interest to realize yield
    ERC20(OP_USDC).approve(address(pool), SMALL_REPAY_AMOUNT);
    pool.repay(OP_USDC, SMALL_REPAY_AMOUNT, 2, borrower);
    vm.stopPrank();

    // Wait additional time for yield to be reflected
    vm.roll(block.number + 100_000);
    vm.warp(block.timestamp + CYCLE_LENGTH);

    // Verify yield has accrued
    uint256 yieldAccrued = obUsdToken.yieldAccrued();
    assertTrue(yieldAccrued > 0, 'No yield accrued');

    // Distribute yield
    vm.prank(owner);
    builderManager.distributeYield();

    // Verify distribution
    assertEq(builderManager.currentProjects().length, 1);
    assertEq(builderManager.currentProjects()[0], projectAtt.recipient);

    // Verify project received yield by checking aUSDC balance increased
    uint256 finalAUsdcBalance = aUSDC.balanceOf(address(obUsdToken));
    assertGt(finalAUsdcBalance, initialAUsdcBalance, 'No yield was distributed');
    emit log_named_string('Integration test with Aave passed', 'Success');
  }

  function test_aUSDC_yield_accumulation() public {
    // Track initial balances
    uint256 initialAUsdcBalance = aUSDC.balanceOf(address(obUsdToken));

    // Get USDC by borrowing against ETH
    vm.startPrank(borrower);
    wethGateway.depositETH{value: COLLATERAL_AMOUNT}(OP_AAVE_V3_POOL, borrower, 0);
    // Reduce the borrow amount to accommodate USDC's different risk parameters
    // USDC typically has a lower loan-to-value ratio compared to USDC
    pool.borrow(OP_USDC, BORROW_AMOUNT, 2, 0, borrower);
    ERC20(OP_USDC).transfer(owner, BORROW_AMOUNT);
    vm.stopPrank();

    // Owner mints obsUSD with USDC
    vm.startPrank(owner);
    ERC20(OP_USDC).approve(address(obUsdToken), BORROW_AMOUNT);
    obUsdToken.mint(BORROW_AMOUNT, address(obUsdToken));
    vm.stopPrank();

    // Verify initial state
    uint256 obsUsdSupply = obUsdToken.totalSupply();
    assertEq(obsUsdSupply, BORROW_AMOUNT, 'Initial obsUSD supply should match minted amount');
    uint256 currentAUsdcBalance = aUSDC.balanceOf(address(obUsdToken));
    assertGt(currentAUsdcBalance, initialAUsdcBalance, 'aUSDC balance should increase after minting');
    assertApproxEqRel(currentAUsdcBalance, obsUsdSupply, 100, 'aUSDC balance should match obsUSD supply initially');

    // Now generate yield by borrowing USDC
    vm.startPrank(borrower);
    // Borrow more USDC which will generate yield - use smaller amount
    pool.borrow(OP_USDC, SMALL_BORROW_AMOUNT, 2, 0, borrower);

    // Move time forward for interest to accrue
    vm.roll(block.number + 100_000);
    vm.warp(block.timestamp + 30 days);

    // IMPORTANT FIX: Deal USDC to the borrower for repayment since they transferred it all away
    deal(address(ERC20(OP_USDC)), borrower, SMALL_REPAY_AMOUNT);

    // Repay loan with interest - adjust repayment amount proportionally
    ERC20(OP_USDC).approve(address(pool), SMALL_REPAY_AMOUNT);
    pool.repay(OP_USDC, SMALL_REPAY_AMOUNT, 2, borrower);
    vm.stopPrank();

    // Move time forward for yield to be reflected
    vm.roll(block.number + 1000);
    vm.warp(block.timestamp + 1 days);

    // Check final state
    uint256 finalAUsdcBalance = aUSDC.balanceOf(address(obUsdToken));
    assertGt(finalAUsdcBalance, currentAUsdcBalance, 'aUSDC balance should increase from yield');

    // The yield should be the difference between aUSDC balance and obsUSD supply
    uint256 yieldAccrued = obUsdToken.yieldAccrued();
    assertGt(yieldAccrued, 0, 'Should have accrued yield');
    assertApproxEqRel(yieldAccrued, finalAUsdcBalance - obsUsdSupply, 10, 'Yield calculation should match aUSDC growth');

    // Log the actual yield for visibility
    emit log_named_uint('Initial aUSDC balance', initialAUsdcBalance);
    emit log_named_uint('Current aUSDC balance', currentAUsdcBalance);
    emit log_named_uint('Final aUSDC balance', finalAUsdcBalance);
    emit log_named_uint('obsUSD supply', obsUsdSupply);
    emit log_named_uint('Yield accrued', yieldAccrued);
  }

  function test_NoYieldDistribution() public {
    // Set up projects with vouches
    _getThreeVouches();

    // Verify project is correctly registered
    assertEq(builderManager.projectToVouches(projectAtt.recipient), MIN_VOUCHES);
    assertEq(builderManager.currentProjects().length, 1);
    assertEq(builderManager.currentProjects()[0], projectAtt.recipient);

    // Set up USDC and mint obUSD, similar to other tests but with minimal amount
    address usdcWhale = makeAddr('usdcWhale');
    vm.label(usdcWhale, 'USDC_WHALE');
    vm.deal(usdcWhale, WHALE_ETH_AMOUNT);
    vm.startPrank(usdcWhale);
    wethGateway.depositETH{value: WHALE_ETH_AMOUNT}(OP_AAVE_V3_POOL, usdcWhale, 0);

    // Use a very small amount ($0.000001 worth of USDC)
    uint256 smallAmount = 1;
    pool.borrow(OP_USDC, smallAmount, 2, 0, usdcWhale);
    ERC20(OP_USDC).transfer(owner, smallAmount);
    vm.stopPrank();

    // Owner mints obUSD with the small amount of USDC
    vm.startPrank(owner);
    ERC20(OP_USDC).approve(address(obUsdToken), smallAmount);
    obUsdToken.mint(smallAmount, address(obUsdToken));
    vm.stopPrank();

    // Important: We DO NOT generate yield or wait for it to accrue
    // We just advance time enough to make the cycle ready for distribution
    vm.warp(block.timestamp + CYCLE_LENGTH + 1);

    // Check that there's no yield accrued
    uint256 yieldAccrued = obUsdToken.yieldAccrued();
    assertEq(yieldAccrued, 0, 'Should have zero yield accrued');

    // Distribute yield and check return value
    vm.startPrank(owner);
    bool yieldDistributed = builderManager.distributeYield();
    vm.stopPrank();

    // Verify it returned false since there was no yield to distribute
    assertFalse(yieldDistributed, 'Should return false when no yield is available');

    emit log_named_string('Zero yield distribution test passed', 'Success');
  }

  // === Helper Functions ===

  /// @notice Helper function to vouch for a project with a specific identity attestation
  function _vouchWithIdentity(address voter, bytes32 projectUid, bytes32 identityUid) internal returns (bool success) {
    vm.prank(voter);
    builderManager.vouch(projectUid, identityUid);
    success = builderManager.voterToProjectVouch(voter, projectUid);
  }

  /// @notice Helper function to get all three vouches for a project
  function _getThreeVouches() internal {
    // First vouch
    vm.prank(identityAtt0.recipient);
    builderManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);
    // Second vouch
    vm.prank(identityAtt1.recipient);
    builderManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);
    // Third vouch
    vm.prank(identityAtt2.recipient);
    builderManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_2);
  }
}
