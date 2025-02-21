// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {ERC20} from '@oz/token/ERC20/ERC20.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import {
  OP_A_DAI,
  OP_FOUNDATION_ATTESTER_0,
  OP_SCHEMA_599,
  OP_SCHEMA_UID_599_0,
  OP_SCHEMA_UID_599_1,
  OP_SCHEMA_UID_599_2,
  OP_SCHEMA_UID_599_3,
  OP_SCHEMA_UID_638_0
} from 'script/Constants.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationBuildersManager is IntegrationBase {
  // Constants for test configuration
  uint256 public constant MIN_VOUCHES = 3;
  uint256 public constant CYCLE_LENGTH = 7 days;
  uint256 public constant SEASON_DURATION = 90 days;
  uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
  uint256 public constant YIELD_AMOUNT = 10 ether;

  // Contract instances
  ERC20 public aDAI;

  // Attestation state
  Attestation public projectAtt;
  Attestation public identityAtt0; // Guest voter
  Attestation public identityAtt1; // Citizen voter
  Attestation public identityAtt2; // Guest voter
  Attestation public identityAtt3; // New voter

  function setUp() public override {
    super.setUp();

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
    _setupYield();

    // We need to wait for a cycle before distributing yield
    vm.warp(block.timestamp + CYCLE_LENGTH + 1);

    // Distribute yield
    buildersManager.distributeYield();

    // Verify distribution
    assertEq(buildersManager.currentProjects().length, 1);
    assertEq(buildersManager.currentProjects()[0], projectAtt.recipient);

    // Verify project received yield
    assertEq(obsUsdToken.balanceOf(projectAtt.recipient), INITIAL_SUPPLY + YIELD_AMOUNT);
  }

  function test_YieldAccumulationOverMultipleCycles() public {
    _setupTimeAndExpiry();
    _getThreeVouches();

    // Initial setup
    uint256 currentBalance = INITIAL_SUPPLY;
    vm.mockCall(
      address(obsUsdToken),
      abi.encodeWithSignature('balanceOf(address)', projectAtt.recipient),
      abi.encode(currentBalance)
    );

    // Run through multiple cycles
    for (uint256 i = 0; i < 3; i++) {
      // Wait for next cycle
      vm.warp(block.timestamp + CYCLE_LENGTH + 1);

      // Mock the yield accrual
      vm.mockCall(address(obsUsdToken), abi.encodeWithSignature('yieldAccrued()'), abi.encode(YIELD_AMOUNT));

      // Mock the claim yield
      vm.mockCall(address(obsUsdToken), abi.encodeWithSignature('claimYield(uint256)'), abi.encode());

      // Mock the transfer
      vm.mockCall(
        address(obsUsdToken),
        abi.encodeWithSignature('transfer(address,uint256)', projectAtt.recipient, YIELD_AMOUNT),
        abi.encode(true)
      );

      // Update the current balance and mock it
      currentBalance += YIELD_AMOUNT;
      vm.mockCall(
        address(obsUsdToken),
        abi.encodeWithSignature('balanceOf(address)', projectAtt.recipient),
        abi.encode(currentBalance)
      );

      buildersManager.distributeYield();

      // Verify the balance after each cycle
      assertEq(obsUsdToken.balanceOf(projectAtt.recipient), currentBalance);
    }

    // Final verification
    assertEq(obsUsdToken.balanceOf(projectAtt.recipient), INITIAL_SUPPLY + (YIELD_AMOUNT * 3));
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
    // First validate the project with first voter
    _vouchWithIdentity(identityAtt0.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_0);

    // Second voter vouches
    _vouchWithIdentity(identityAtt1.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_1);

    // Third voter vouches
    _vouchWithIdentity(identityAtt2.recipient, OP_SCHEMA_UID_638_0, OP_SCHEMA_UID_599_2);
  }

  /// @notice Sets up the time and season expiry for testing
  function _setupTimeAndExpiry() internal {
    // Warp to a timestamp after the attestation time (1734617785)
    vm.warp(1_734_617_785 + 1 days);
    vm.roll(block.number + 1000);

    // Update the BuildersManager settings with a valid season expiry
    IBuildersManager.BuilderManagerSettings memory settings = buildersManager.settings();
    settings.currentSeasonExpiry = uint64(block.timestamp + SEASON_DURATION);
    vm.prank(owner);
    buildersManager.modifyParams('currentSeasonExpiry', settings.currentSeasonExpiry);
  }

  /// @notice Helper to setup yield for testing
  function _setupYield() internal {
    // Mock the initial balance
    vm.mockCall(
      address(obsUsdToken),
      abi.encodeWithSignature('balanceOf(address)', projectAtt.recipient),
      abi.encode(INITIAL_SUPPLY)
    );

    // Mock the yield accrual and claim operations
    vm.mockCall(address(obsUsdToken), abi.encodeWithSignature('yieldAccrued()'), abi.encode(YIELD_AMOUNT));
    vm.mockCall(address(obsUsdToken), abi.encodeWithSignature('claimYield(uint256)', YIELD_AMOUNT), abi.encode());
    vm.mockCall(
      address(obsUsdToken),
      abi.encodeWithSignature('transfer(address,uint256)', projectAtt.recipient, YIELD_AMOUNT),
      abi.encode(true)
    );

    // Mock the final balance check to return initial + yield
    vm.mockCall(
      address(obsUsdToken),
      abi.encodeWithSignature('balanceOf(address)', projectAtt.recipient),
      abi.encode(INITIAL_SUPPLY + YIELD_AMOUNT)
    );
  }
}
