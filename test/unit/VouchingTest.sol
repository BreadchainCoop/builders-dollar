// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation} from '@eas/Common.sol';
import {IBuildersManager} from 'contracts/BuildersManager.sol';
import {OP_SCHEMA_638} from 'script/Constants.sol';
import {BaseTest} from 'test/unit/BaseTest.sol';

contract UnitVouchingTest is BaseTest {
  bytes32 public projectAttestation = bytes32(uint256(1));
  bytes32 public projectRefId = bytes32(uint256(3));
  address public project = address(0x123);

  function test_VouchWhenProjectAndIdentityAttestationsAreValid() public {
    // Setup voter attestation
    _setupVoterAttestation();
    buildersManager.validateOptimismVoter(identityAttestation);

    // Setup project attestation
    bytes memory attestationData = abi.encode(projectRefId, '');
    Attestation memory mockProjectAttestation =
      _createMockAttestation(projectAttestation, OP_SCHEMA_638, project, address(this), attestationData);
    _mockEASAttestation(projectAttestation, mockProjectAttestation);
    vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', projectRefId), abi.encode(true));

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.ProjectValidated(projectAttestation, project);

    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.VouchRecorded(address(this), project, projectAttestation);

    // Vouch for project
    buildersManager.vouch(projectAttestation);
  }

  function test_VouchWhenProjectAttestationIsInvalid() public {
    // Setup voter attestation
    _setupVoterAttestation();
    buildersManager.validateOptimismVoter(identityAttestation);

    // Setup invalid project attestation
    vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', projectRefId), abi.encode(false));

    // Mock invalid project attestation
    Attestation memory mockProjectAttestation =
      _createMockAttestation(projectAttestation, OP_SCHEMA_638, project, address(this), abi.encode(projectRefId, ''));
    _mockEASAttestation(projectAttestation, mockProjectAttestation);

    // Expect revert
    vm.expectRevert(IBuildersManager.InvalidProjectUid.selector);
    buildersManager.vouch(projectAttestation);
  }

  function test_VouchWhenVoterIsNotEligible() public {
    // Setup project attestation
    _setupProjectAttestation(project, projectAttestation, projectRefId);

    // Expect revert since voter is not eligible
    vm.expectRevert(IBuildersManager.IdAttestationRequired.selector);
    buildersManager.vouch(projectAttestation);
  }

  function test_VouchWhenProjectAlreadyVouched() public {
    // Setup project attestation
    _setupProjectAttestation(project, projectAttestation, projectRefId);

    // Setup voter attestation
    _setupVoterAttestation();

    // Validate voter
    buildersManager.validateOptimismVoter(identityAttestation);

    // First vouch should succeed
    buildersManager.vouch(projectAttestation);

    // Second vouch should fail
    vm.expectRevert(IBuildersManager.AlreadyVouched.selector);
    buildersManager.vouch(projectAttestation);
  }
}
