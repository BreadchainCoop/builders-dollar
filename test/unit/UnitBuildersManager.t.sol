// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {Ownable} from '@oz/access/Ownable.sol';
import {IBuildersManager} from 'contracts/BuildersManager.sol';
import {OP_SCHEMA_599, OP_SCHEMA_638} from 'script/Constants.sol';
import {BaseTest} from 'test/unit/BaseTest.sol';

contract UnitBuildersManager is BaseTest {
  function test_TOKENWhenCalled() external view {
    assertEq(address(buildersManager.TOKEN()), token);
  }

  function test_EASWhenCalled() external view {
    assertEq(address(buildersManager.EAS()), eas);
  }

  function test_OptimismFoundationAttesterWhenTheAttesterIsAnOptimismFoundationAttester() external view {
    assertTrue(buildersManager.optimismFoundationAttester(address(this)));
  }

  function test_OptimismFoundationAttesterWhenTheAttesterIsNotAnOptimismFoundationAttester() external view {
    assertFalse(buildersManager.optimismFoundationAttester(address(0x123)));
  }

  function test_EligibleVoterWhenTheVoterIsEligibleAndVouched() external {
    address voter = address(0x123);
    mockEligibleVoter(voter, true);
    assertTrue(buildersManager.eligibleVoter(voter));
  }

  function test_EligibleVoterWhenTheVoterIsNotEligibleOrVouched() external {
    address voter = address(0x123);
    mockEligibleVoter(voter, false);
    assertFalse(buildersManager.eligibleVoter(voter));
  }

  function test_EligibleProjectWhenTheProjectIsEligible() external {
    bytes32 uid = bytes32(uint256(1));
    address project = address(0x123);
    mockEligibleProject(uid, project);
    assertEq(buildersManager.eligibleProject(uid), project);
  }

  function test_EligibleProjectWhenTheProjectIsNotEligible() external {
    bytes32 uid = bytes32(uint256(1));
    mockEligibleProject(uid, address(0));
    assertEq(buildersManager.eligibleProject(uid), address(0));
  }

  function test_ProjectToExpiryWhenTheProjectIsEligible() external {
    address project = address(0x123);
    uint256 expiry = block.timestamp + 90 days;
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.projectToExpiry.selector, project),
      abi.encode(expiry)
    );
    assertEq(buildersManager.projectToExpiry(project), expiry);
  }

  function test_ProjectToExpiryWhenTheProjectIsNotEligible() external {
    address project = address(0x123);
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.projectToExpiry.selector, project),
      abi.encode(0)
    );
    assertEq(buildersManager.projectToExpiry(project), 0);
  }

  function test_ProjectToVouchesWhenTheProjectIsEligible() external {
    address project = address(0x123);
    uint256 vouches = 3;
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.projectToVouches.selector, project),
      abi.encode(vouches)
    );
    assertEq(buildersManager.projectToVouches(project), vouches);
  }

  function test_ProjectToVouchesWhenTheProjectIsNotEligible() external {
    address project = address(0x123);
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.projectToVouches.selector, project),
      abi.encode(0)
    );
    assertEq(buildersManager.projectToVouches(project), 0);
  }

  function test_VoterToProjectVouchWhenTheVoterHasVouchedForTheProject() external {
    address voter = address(0x123);
    bytes32 projectAttestation = bytes32(uint256(1));
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.voterToProjectVouch.selector, voter, projectAttestation),
      abi.encode(true)
    );
    assertTrue(buildersManager.voterToProjectVouch(voter, projectAttestation));
  }

  function test_VoterToProjectVouchWhenTheVoterHasNotVouchedForTheProject() external {
    address voter = address(0x123);
    bytes32 projectAttestation = bytes32(uint256(1));
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.voterToProjectVouch.selector, voter, projectAttestation),
      abi.encode(false)
    );
    assertFalse(buildersManager.voterToProjectVouch(voter, projectAttestation));
  }

  function test_SettingsReturnsTheSettings() external view {
    IBuildersManager.BuilderManagerSettings memory settings = buildersManager.settings();
    assertEq(settings.cycleLength, 7 days);
    assertEq(settings.seasonDuration, 90 days);
    assertEq(settings.minVouches, 3);
    assertEq(settings.optimismFoundationAttesters[0], address(this));
  }

  function test_CurrentProjectsWhenThereAreProjects() external {
    address[] memory projects = new address[](2);
    projects[0] = address(0x1);
    projects[1] = address(0x2);
    mockCurrentProjects(projects);

    address[] memory currentProjects = buildersManager.currentProjects();
    assertEq(currentProjects.length, 2);
    assertEq(currentProjects[0], projects[0]);
    assertEq(currentProjects[1], projects[1]);
  }

  function test_CurrentProjectsWhenThereAreNoProjects() external {
    address[] memory emptyProjects = new address[](0);
    mockCurrentProjects(emptyProjects);

    address[] memory currentProjects = buildersManager.currentProjects();
    assertEq(currentProjects.length, 0);
  }

  function test_OptimismFoundationAttestersWhenThereAreAttesters() external {
    address[] memory attesters = new address[](1);
    attesters[0] = address(this);
    mockOptimismFoundationAttesters(attesters);

    address[] memory foundationAttesters = buildersManager.optimismFoundationAttesters();
    assertEq(foundationAttesters.length, 1);
    assertEq(foundationAttesters[0], address(this));
  }

  function test_OptimismFoundationAttestersWhenThereAreNoAttesters() external {
    address[] memory emptyAttesters = new address[](0);
    mockOptimismFoundationAttesters(emptyAttesters);

    address[] memory foundationAttesters = buildersManager.optimismFoundationAttesters();
    assertEq(foundationAttesters.length, 0);
  }

  function test_ValidateOptimismVoterWhenPassingInvalidIdentityAttestation() external {
    bytes32 invalidAttestation = bytes32(uint256(1));
    mockValidateOptimismVoter(invalidAttestation, false);

    assertFalse(buildersManager.validateOptimismVoter(invalidAttestation));
  }

  function test_ModifyParamsWhenPassingValidParamAndValue() external {
    bytes32 param = 'cycleLength';
    uint64 value = 14 days;

    // Mock the current settings
    IBuildersManager.BuilderManagerSettings memory currentSettings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 7 days,
      lastClaimedTimestamp: uint64(block.timestamp),
      currentSeasonExpiry: uint64(block.timestamp + 90 days),
      seasonDuration: 90 days,
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    mockSettings(currentSettings);

    buildersManager.modifyParams(param, uint256(value));

    // Update the expected settings
    currentSettings.cycleLength = value;
    mockSettings(currentSettings);

    IBuildersManager.BuilderManagerSettings memory settings = buildersManager.settings();
    assertEq(settings.cycleLength, value);
  }

  function test_ModifyParamsWhenPassingInvalidParamOrValue() external {
    bytes32 invalidParam = 'invalidParam';
    uint256 value = 100;

    vm.expectRevert(IBuildersManager.InvalidParameter.selector);
    buildersManager.modifyParams(invalidParam, value);
  }

  function test_UpdateOpFoundationAttesterWhenPassingValidAttesterAndStatus() external {
    address attester = address(0x123);
    bool status = true;

    buildersManager.updateOpFoundationAttester(attester, status);
    assertTrue(buildersManager.optimismFoundationAttester(attester));
  }

  function test_BatchUpdateOpFoundationAttestersWhenPassingValidAttestersAndStatuses() external {
    address[] memory attesters = new address[](2);
    attesters[0] = address(0x1);
    attesters[1] = address(0x2);
    bool[] memory statuses = new bool[](2);
    statuses[0] = true;
    statuses[1] = true;

    buildersManager.batchUpdateOpFoundationAttesters(attesters, statuses);

    assertTrue(buildersManager.optimismFoundationAttester(attesters[0]));
    assertTrue(buildersManager.optimismFoundationAttester(attesters[1]));
  }

  function test_BatchUpdateOpFoundationAttestersWhenPassingInvalidAttestersOrStatuses() external {
    address[] memory attesters = new address[](2);
    attesters[0] = address(0);
    attesters[1] = address(0x2);
    bool[] memory statuses = new bool[](1);
    statuses[0] = true;

    vm.expectRevert(IBuildersManager.InvalidLength.selector);
    buildersManager.batchUpdateOpFoundationAttesters(attesters, statuses);
  }

  // Test that only owner can modify parameters
  function test_ModifyParams() public {
    bytes32 param = 'cycleLength';
    uint256 newValue = 14 days;

    // Should revert when called by non-owner
    vm.prank(address(0xdead));
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xdead)));
    buildersManager.modifyParams(param, newValue);
  }

  // Test that attester management works
  function test_UpdateOpFoundationAttester() public {
    address newAttester = address(0x123);

    // Test adding new attester
    buildersManager.updateOpFoundationAttester(newAttester, true);
    assertTrue(buildersManager.optimismFoundationAttester(newAttester));

    // Test removing attester
    buildersManager.updateOpFoundationAttester(newAttester, false);
    assertFalse(buildersManager.optimismFoundationAttester(newAttester));

    // Test revert on no change
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.AlreadyUpdated.selector, newAttester));
    buildersManager.updateOpFoundationAttester(newAttester, false);
  }

  // Test batch attester updates
  function test_BatchUpdateOpFoundationAttesters() public {
    address[] memory attesters = new address[](2);
    attesters[0] = address(0x1);
    attesters[1] = address(0x2);
    bool[] memory statuses = new bool[](2);
    statuses[0] = true;
    statuses[1] = true;

    // Test successful batch update
    buildersManager.batchUpdateOpFoundationAttesters(attesters, statuses);
    assertTrue(buildersManager.optimismFoundationAttester(attesters[0]));
    assertTrue(buildersManager.optimismFoundationAttester(attesters[1]));

    // Test revert on length mismatch
    bool[] memory invalidStatuses = new bool[](1);
    vm.expectRevert(IBuildersManager.InvalidLength.selector);
    buildersManager.batchUpdateOpFoundationAttesters(attesters, invalidStatuses);
  }

  // Test project validation
  function test_ValidateProject() public {
    bytes32 attestation = bytes32(uint256(1));
    address project = address(0x123);
    uint256 expectedExpiry = block.timestamp + 90 days;

    // Create properly encoded attestation data
    bytes32 projectRefId = bytes32(uint256(2)); // Reference ID
    bytes memory extraData = hex'1234'; // Some arbitrary bytes
    bytes memory attestationData = abi.encode(projectRefId, extraData);

    // Mock the EAS.getAttestation call for project attestation
    Attestation memory mockAttestation = Attestation({
      uid: attestation,
      schema: OP_SCHEMA_638,
      time: uint64(block.timestamp),
      expirationTime: uint64(block.timestamp + 365 days),
      revocationTime: uint64(0),
      refUID: EMPTY_UID,
      recipient: project,
      attester: address(this),
      revocable: true,
      data: attestationData
    });

    vm.mockCall(
      address(eas), abi.encodeWithSignature('getAttestation(bytes32)', attestation), abi.encode(mockAttestation)
    );

    // Mock isAttestationValid call for the project reference ID
    vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', projectRefId), abi.encode(true));

    bytes memory identityData = abi.encode(320_694, '7', 'Citizen', 'C', '3.2');

    // First make ourselves an eligible voter
    bytes32 identityAttestation = bytes32(uint256(3));
    Attestation memory mockIdentityAttestation = Attestation({
      uid: identityAttestation,
      schema: OP_SCHEMA_599,
      time: uint64(block.timestamp),
      expirationTime: uint64(block.timestamp + 365 days),
      revocationTime: uint64(0),
      refUID: EMPTY_UID,
      recipient: address(this),
      attester: address(this),
      revocable: true,
      data: identityData
    });

    vm.mockCall(
      address(eas),
      abi.encodeWithSignature('getAttestation(bytes32)', identityAttestation),
      abi.encode(mockIdentityAttestation)
    );

    // Validate ourselves as a voter first
    buildersManager.validateOptimismVoter(identityAttestation);

    // Now call vouch which internally validates the project
    buildersManager.vouch(attestation);

    // Verify project was validated
    assertEq(buildersManager.eligibleProject(attestation), project);
    assertEq(buildersManager.projectToExpiry(project), expectedExpiry, 'Project expiry time mismatch');
  }

  // Test batch operations with invalid inputs
  function test_BatchOperationsInvalid() public {
    // Test batch update with mismatched array lengths
    address[] memory attesters = new address[](2);
    attesters[0] = address(0x1);
    attesters[1] = address(0x2);
    bool[] memory statuses = new bool[](1);
    statuses[0] = true;

    vm.expectRevert(IBuildersManager.InvalidLength.selector);
    buildersManager.batchUpdateOpFoundationAttesters(attesters, statuses);

    // Test batch update with empty arrays
    address[] memory emptyAttesters = new address[](0);
    bool[] memory emptyStatuses = new bool[](0);
    buildersManager.batchUpdateOpFoundationAttesters(emptyAttesters, emptyStatuses);

    // Test batch update with duplicate attesters
    address[] memory duplicateAttesters = new address[](2);
    duplicateAttesters[0] = address(0x1);
    duplicateAttesters[1] = address(0x1);
    bool[] memory duplicateStatuses = new bool[](2);
    duplicateStatuses[0] = true;
    duplicateStatuses[1] = true;

    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.AlreadyUpdated.selector, address(0x1)));
    buildersManager.batchUpdateOpFoundationAttesters(duplicateAttesters, duplicateStatuses);
  }
}
