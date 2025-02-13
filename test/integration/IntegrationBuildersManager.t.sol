// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation} from '@eas/Common.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import {OP_FOUNDATION_ATTESTER_1, OP_SCHEMA_638, OP_SCHEMA_UID_0} from 'script/Registry.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationBuildersManager is IntegrationBase {
  // todo get real attesters
  address public attester2 = makeAddr('attester2');
  address public attester3 = makeAddr('attester3');

  function setUp() public override {
    super.setUp();
    address[] memory attesters = new address[](2);
    attesters[0] = attester2;
    attesters[1] = attester3;

    bool[] memory statuses = new bool[](2);
    statuses[0] = true;
    statuses[1] = true;

    vm.prank(owner);
    // Add OP Foundation attesters to allow validation
    buildersManager.batchUpdateOpFoundationAttesters(attesters, statuses);
  }

  // function test_ValidateProjectWithOnchainAttestation() public {
  //   // Get the onchain attestation
  //   Attestation memory attestation = eas.getAttestation(OP_SCHEMA_UID_0);

  //   // Verify the attestation has the correct schema and attester
  //   assertEq(attestation.schema, OP_SCHEMA_638);
  //   assertEq(attestation.attester, OP_FOUNDATION_ATTESTER_1);

  //   // Decode the project reference ID from the attestation data
  //   (bytes32 projectRefId,) = abi.decode(attestation.data, (bytes32, bytes));

  //   // Verify the project reference is valid
  //   assertTrue(eas.isAttestationValid(projectRefId));

  //   // Make a voter eligible to vouch
  //   bytes32 voterUid = bytes32(uint256(1000));
  //   _makeVoterEligible(address(this), voterUid);

  //   // Vouch for the project using the onchain attestation
  //   buildersManager.vouch(OP_SCHEMA_UID_0);

  //   // Verify the project was properly validated
  //   address expectedProject = attestation.recipient;
  //   assertEq(buildersManager.eligibleProject(OP_SCHEMA_UID_0), expectedProject);
  //   assertTrue(buildersManager.projectToExpiry(expectedProject) > block.timestamp);
  // }

  // function test_VouchForOnchainProject() public {
  //   // Get the onchain attestation
  //   Attestation memory attestation = eas.getAttestation(OP_SCHEMA_UID_0);

  //   // Create MIN_VOUCHES number of voters
  //   address[] memory voters = new address[](buildersManager.settings().minVouches);
  //   for (uint256 i = 0; i < voters.length; i++) {
  //     voters[i] = makeAddr(string.concat('voter', vm.toString(i)));
  //     bytes32 voterUid = bytes32(uint256(1000 + i));
  //     _makeVoterEligible(voters[i], voterUid);
  //   }

  //   // Have each voter vouch for the project
  //   for (uint256 i = 0; i < voters.length; i++) {
  //     vm.prank(voters[i]);
  //     buildersManager.vouch(OP_SCHEMA_UID_0);

  //     // Verify the vouch was recorded
  //     assertTrue(buildersManager.voterToProjectVouch(voters[i], OP_SCHEMA_UID_0));
  //   }

  //   // Verify the project reached minimum vouches
  //   assertEq(buildersManager.projectToVouches(attestation.recipient), buildersManager.settings().minVouches);

  //   // Get current projects and verify our project is included
  //   address[] memory currentProjects = buildersManager.currentProjects();
  //   bool found = false;
  //   for (uint256 i = 0; i < currentProjects.length; i++) {
  //     if (currentProjects[i] == attestation.recipient) {
  //       found = true;
  //       break;
  //     }
  //   }
  //   assertTrue(found, 'Project should be in current projects after reaching min vouches');
  // }

  // function test_GetCurrentProjectUidsWithOnchainProject() public {
  //   // Get the onchain attestation
  //   Attestation memory attestation = eas.getAttestation(OP_SCHEMA_UID_0);

  //   // Make MIN_VOUCHES voters eligible and have them vouch
  //   for (uint256 i = 0; i < buildersManager.settings().minVouches; i++) {
  //     address voter = makeAddr(string.concat('voter', vm.toString(i)));
  //     bytes32 voterUid = bytes32(uint256(1000 + i));
  //     _makeVoterEligible(voter, voterUid);

  //     vm.prank(voter);
  //     buildersManager.vouch(OP_SCHEMA_UID_0);
  //   }

  //   // Get current project UIDs
  //   bytes32[] memory uids = buildersManager.currentProjectUids();

  //   // Verify our project's UID is included
  //   bool found = false;
  //   for (uint256 i = 0; i < uids.length; i++) {
  //     if (uids[i] == OP_SCHEMA_UID_0) {
  //       found = true;
  //       break;
  //     }
  //   }
  //   assertTrue(found, 'Project UID should be in current project UIDs');
  // }

  // function test_RevertWhenVouchingTwiceForOnchainProject() public {
  //   // Make voter eligible
  //   bytes32 voterUid = bytes32(uint256(1000));
  //   _makeVoterEligible(address(this), voterUid);

  //   // First vouch should succeed
  //   buildersManager.vouch(OP_SCHEMA_UID_0);

  //   // Second vouch should fail
  //   vm.expectRevert(IBuildersManager.AlreadyVouched.selector);
  //   buildersManager.vouch(OP_SCHEMA_UID_0);
  // }

  // --- Helper functions --- //

  // Helper function to make a voter eligible using real EAS attestations
  function _makeVoterEligible(address voter, bytes32 identityAttestation) internal {
    // Create attestation data with a valid reference
    bytes32 refId = bytes32(uint256(1)); // Use a simple reference ID
    bytes memory attestationData = abi.encode(refId, '');

    // Mock the identity attestation
    vm.mockCall(
      address(eas),
      abi.encodeWithSignature('getAttestation(bytes32)', identityAttestation),
      abi.encode(
        identityAttestation, // uid
        bytes32(0), // schema (not OP_SCHEMA_638 since it's an identity attestation)
        uint64(block.timestamp), // time
        uint64(block.timestamp + 365 days), // expirationTime
        uint64(0), // revocationTime
        bytes32(0), // refUID
        voter, // recipient
        OP_FOUNDATION_ATTESTER_1, // attester
        true, // revocable
        attestationData // data
      )
    );

    // Mock the reference attestation as valid
    vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', refId), abi.encode(true));

    // Validate the voter
    vm.prank(voter);
    buildersManager.validateOptimismVoter(identityAttestation);
  }
}
