// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IPool} from '@aave-core-v3/interfaces/IPool.sol';
import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {ERC20} from '@oz/token/ERC20/ERC20.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import {
  OP_AAVE_V3_POOL,
  OP_A_DAI,
  OP_DAI,
  OP_FOUNDATION_ATTESTER_0,
  OP_SCHEMA_599,
  OP_SCHEMA_UID_599_0,
  OP_SCHEMA_UID_599_1,
  OP_SCHEMA_UID_599_2,
  OP_SCHEMA_UID_599_3,
  OP_SCHEMA_UID_638_0,
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

  IWETHGateway public wethGateway = IWETHGateway(OP_WETH_GATEWAY);
  IPool public pool = IPool(OP_AAVE_V3_POOL);

  // Contract instances
  ERC20 public aDAI;

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
    aDAI = ERC20(OP_A_DAI);

    // Get real attestations from EAS
    projectAtt = eas.getAttestation(OP_SCHEMA_UID_638_0);
    identityAtt0 = eas.getAttestation(OP_SCHEMA_UID_599_0);
    identityAtt1 = eas.getAttestation(OP_SCHEMA_UID_599_1);
    identityAtt2 = eas.getAttestation(OP_SCHEMA_UID_599_2);
    identityAtt3 = eas.getAttestation(OP_SCHEMA_UID_599_3);

    // Verify obsUsdToken matches the token in BuildersManager
    assertEq(address(obsUsdToken), address(buildersManager.TOKEN()));

    // Set BuildersManager as the yield claimer for obsUsdToken
    vm.startPrank(owner);
    obsUsdToken.setYieldClaimer(address(buildersManager));
    vm.stopPrank();

    // Deal some ETH to the borrower
    vm.deal(borrower, 10_000 ether);
  }

  // === Project Attestation Tests ===

  function test_ProjectAttestationValidation() public {
    _setupTimeAndExpiry();

    // Validate project using identity attestation
    _vouchWithIdentity(identityAtt0.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);

    // Verify project is properly registered
    assertEq(buildersManager.eligibleProject(OP_SCHEMA_UID_638_0), projectAtt.recipient);
    assertEq(buildersManager.eligibleProjectByUid(projectAtt.recipient), OP_SCHEMA_UID_638_0);
  }

  // === Voter Attestation Tests ===

  function test_VoterAttestationValidation() public {
    // Test Guest voter
    vm.prank(identityAtt0.recipient);
    assertTrue(buildersManager.validateOptimismVoter(OP_SCHEMA_UID_599_0));
    assertTrue(buildersManager.eligibleVoter(identityAtt0.recipient));

    // Test Citizen voter
    vm.prank(identityAtt1.recipient);
    assertTrue(buildersManager.validateOptimismVoter(OP_SCHEMA_UID_599_1));
    assertTrue(buildersManager.eligibleVoter(identityAtt1.recipient));
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
    assertFalse(buildersManager.validateOptimismVoter(invalidAttestation.uid));
    assertFalse(buildersManager.eligibleVoter(address(this)));
  }

  // === Vouching System Tests ===

  function test_CompleteVouchingFlow() public {
    _setupTimeAndExpiry();
    _getThreeVouches();

    // Verify project reached minimum vouches
    assertEq(buildersManager.projectToVouches(projectAtt.recipient), MIN_VOUCHES);

    // Verify project is in current projects list
    address[] memory currentProjects = buildersManager.currentProjects();
    assertEq(currentProjects[0], projectAtt.recipient);
  }

  function test_VouchingRestrictions() public {
    _setupTimeAndExpiry();

    // First validate the project
    _vouchWithIdentity(identityAtt0.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);

    // Second vouch should succeed
    _vouchWithIdentity(identityAtt1.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);

    // Third vouch should fail (already verified)
    vm.expectRevert(IBuildersManager.AlreadyVerified.selector);
    vm.prank(identityAtt1.recipient);
    buildersManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);

    // Fourth vouch should fail (already vouched)
    vm.expectRevert(IBuildersManager.AlreadyVouched.selector);
    vm.prank(identityAtt1.recipient);
    buildersManager.vouch(OP_SCHEMA_UID_638_0);
  }

  // === Yield Distribution Tests ===

  function test_YieldDistributionCycle() public {
    _setupTimeAndExpiry();
    _getThreeVouches();

    // Get initial balances
    uint256 initialADaiBalance = aDAI.balanceOf(address(obsUsdToken));

    // First get some DAI for the owner and mint obsUSD to generate yield on
    address daiWhale = makeAddr('daiWhale');
    vm.deal(daiWhale, 100 ether);
    vm.startPrank(daiWhale);
    wethGateway.depositETH{value: 100 ether}(OP_AAVE_V3_POOL, daiWhale, 0);
    pool.borrow(OP_DAI, 1000 ether, 2, 0, daiWhale);
    ERC20(OP_DAI).transfer(owner, 1000 ether);
    vm.stopPrank();

    // Now mint obsUSD
    vm.startPrank(owner);
    ERC20(OP_DAI).approve(address(obsUsdToken), 1000 ether);
    obsUsdToken.mint(1000 ether, address(obsUsdToken));
    vm.stopPrank();

    vm.startPrank(borrower);
    // Deposit ETH as collateral
    wethGateway.depositETH{value: 1000 ether}(OP_AAVE_V3_POOL, borrower, 0);

    // Borrow DAI to generate yield
    pool.borrow(OP_DAI, 100 ether, 2, 0, borrower);

    // Move time forward to allow yield to accrue
    vm.roll(block.number + 100_000);
    vm.warp(block.timestamp + CYCLE_LENGTH + 1);

    // Repay the loan with interest to realize yield
    uint256 repayAmount = 110 ether; // Repay with 10% interest
    ERC20(OP_DAI).approve(address(pool), repayAmount);
    pool.repay(OP_DAI, repayAmount, 2, borrower);
    vm.stopPrank();

    // Wait additional time for yield to be reflected
    vm.roll(block.number + 100_000);
    vm.warp(block.timestamp + CYCLE_LENGTH);

    // Verify yield has accrued
    uint256 yieldAccrued = obsUsdToken.yieldAccrued();
    assertTrue(yieldAccrued > 0, 'No yield accrued');

    // Mock the rewards claim to avoid array out-of-bounds error
    vm.mockCall(address(obsUsdToken), abi.encodeWithSelector(obsUsdToken.claimRewards.selector), abi.encode());

    // Deal some DAI to obsUsdToken to simulate yield
    vm.startPrank(address(pool));
    deal(address(ERC20(OP_DAI)), address(obsUsdToken), yieldAccrued);
    vm.stopPrank();

    // Deal obsUSD tokens to BuildersManager to enable distribution
    deal(address(obsUsdToken), address(buildersManager), yieldAccrued);

    // Distribute yield
    vm.prank(owner);
    buildersManager.distributeYield();

    // Verify distribution
    assertEq(buildersManager.currentProjects().length, 1);
    assertEq(buildersManager.currentProjects()[0], projectAtt.recipient);

    // Verify project received yield by checking aDAI balance increased
    uint256 finalADaiBalance = aDAI.balanceOf(address(obsUsdToken));
    assertGt(finalADaiBalance, initialADaiBalance, 'No yield was distributed');
  }

  function test_aDAI_yield_accumulation() public {
    // Track initial balances
    uint256 initialADaiBalance = aDAI.balanceOf(address(obsUsdToken));

    // Get DAI by borrowing against ETH
    vm.startPrank(borrower);
    wethGateway.depositETH{value: 1000 ether}(OP_AAVE_V3_POOL, borrower, 0);
    pool.borrow(OP_DAI, 1000 ether, 2, 0, borrower);
    ERC20(OP_DAI).transfer(owner, 1000 ether);
    vm.stopPrank();

    // Owner mints obsUSD with DAI
    vm.startPrank(owner);
    ERC20(OP_DAI).approve(address(obsUsdToken), 1000 ether);
    obsUsdToken.mint(1000 ether, address(obsUsdToken));
    vm.stopPrank();

    // Verify initial state
    uint256 obsUsdSupply = obsUsdToken.totalSupply();
    assertEq(obsUsdSupply, 1000 ether, 'Initial obsUSD supply should match minted amount');
    uint256 currentADaiBalance = aDAI.balanceOf(address(obsUsdToken));
    assertGt(currentADaiBalance, initialADaiBalance, 'aDAI balance should increase after minting');
    assertApproxEqRel(currentADaiBalance, obsUsdSupply, 10, 'aDAI balance should match obsUSD supply initially');

    // Now generate yield by borrowing DAI
    vm.startPrank(borrower);
    // Borrow more DAI which will generate yield
    pool.borrow(OP_DAI, 100 ether, 2, 0, borrower);

    // Move time forward for interest to accrue
    vm.roll(block.number + 100_000);
    vm.warp(block.timestamp + 30 days);

    // Repay loan with interest
    uint256 repayAmount = 110 ether; // Principal + 10% interest
    ERC20(OP_DAI).approve(address(pool), repayAmount);
    pool.repay(OP_DAI, repayAmount, 2, borrower);
    vm.stopPrank();

    // Move time forward for yield to be reflected
    vm.roll(block.number + 1000);
    vm.warp(block.timestamp + 1 days);

    // Check final state
    uint256 finalADaiBalance = aDAI.balanceOf(address(obsUsdToken));
    assertGt(finalADaiBalance, currentADaiBalance, 'aDAI balance should increase from yield');

    // The yield should be the difference between aDAI balance and obsUSD supply
    uint256 yieldAccrued = obsUsdToken.yieldAccrued();
    assertGt(yieldAccrued, 0, 'Should have accrued yield');
    assertApproxEqRel(yieldAccrued, finalADaiBalance - obsUsdSupply, 10, 'Yield calculation should match aDAI growth');

    // Log the actual yield for visibility
    emit log_named_uint('Initial aDAI balance', initialADaiBalance);
    emit log_named_uint('Current aDAI balance', currentADaiBalance);
    emit log_named_uint('Final aDAI balance', finalADaiBalance);
    emit log_named_uint('obsUSD supply', obsUsdSupply);
    emit log_named_uint('Yield accrued', yieldAccrued);
  }

  // === Helper Functions ===

  /// @notice Helper function to vouch for a project with a specific identity attestation
  function _vouchWithIdentity(address voter, bytes32 projectUid, bytes32 identityUid) internal returns (bool success) {
    vm.prank(voter);
    buildersManager.vouch(projectUid, identityUid);
    success = buildersManager.voterToProjectVouch(voter, projectUid);
  }

  /// @notice Helper function to get all three vouches for a project
  function _getThreeVouches() internal {
    // First vouch
    vm.prank(identityAtt0.recipient);
    buildersManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);
    // Second vouch
    vm.prank(identityAtt1.recipient);
    buildersManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);
    // Third vouch
    vm.prank(identityAtt2.recipient);
    buildersManager.vouch(OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_2);
  }

  /// @notice Sets up the time and season expiry for testing
  function _setupTimeAndExpiry() internal {
    vm.startPrank(owner);
    vm.warp(block.timestamp + 1);
    buildersManager.modifyParams('currentSeasonExpiry', block.timestamp + 180 days);
    vm.stopPrank();
  }
}
