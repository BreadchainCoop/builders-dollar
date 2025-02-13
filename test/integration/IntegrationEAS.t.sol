// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IntegrationBase} from './IntegrationBase.sol';
import {Attestation} from '@eas/Common.sol';
import {SchemaRecord} from '@eas/ISchemaRegistry.sol';
import {
  OP_FOUNDATION_ATTESTER_1,
  OP_SCHEMA_638,
  OP_SCHEMA_UID_0,
  OP_SCHEMA_UID_1,
  OP_SCHEMA_UID_2,
  OP_SCHEMA_UID_3
} from 'script/Registry.sol';

contract IntegrationEAS is IntegrationBase {
  /**
   * @notice reference for attestation attributes at https://optimism.easscan.org/attestation/view/0xa5554839b21b21276b9a5c59ab950d8b56be006fdff636c0273b8bbbc3981b35
   * @dev for attestation OP_SCHEMA_UID_0
   */
  Attestation public referenceAttestation0 = Attestation({
    uid: 0xa5554839b21b21276b9a5c59ab950d8b56be006fdff636c0273b8bbbc3981b35, // bytes32
    schema: 0x8aef6b9adab6252367588ad337f304da1c060cc3190f01d7b72c7e512b9bfb38, // bytes32
    time: 1_734_617_785, // uint64
    expirationTime: 0, // uint64
    revocationTime: 0, // uint64
    refUID: bytes32(0), // bytes32
    recipient: 0xedf4dC5A1420227A2302E8E28b30cF5DC50df24C, // address
    attester: 0xDCF7bE2ff93E1a7671724598b1526F3A33B1eC25, // address
    revocable: true, // bool
    data: '0x4201a4ad6468dff549edc3096367ac4beec946b701f94da7abc11182320d15a300000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000531303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001646617263617374657220536f6369616c20477261706800000000000000000000000000000000000000000000000000000000000000000000000000000000000a31312f32302f32303234000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' // bytes
  });

  Attestation internal _attestation0;
  Attestation internal _attestation1;
  Attestation internal _attestation2;
  Attestation internal _attestation3;

  function setUp() public override {
    super.setUp();
    _attestation0 = eas.getAttestation(OP_SCHEMA_UID_0);
    _attestation1 = eas.getAttestation(OP_SCHEMA_UID_1);
    _attestation2 = eas.getAttestation(OP_SCHEMA_UID_2);
    _attestation3 = eas.getAttestation(OP_SCHEMA_UID_3);
  }

  /// @dev test that the attestations contain the correct schema
  function test_getAttestationSchema() public view {
    SchemaRecord memory _schemaRecord = eas.getSchemaRegistry().getSchema(_attestation1.schema);

    assertEq(_schemaRecord.uid, OP_SCHEMA_638);
    assertEq(_attestation0.schema, OP_SCHEMA_638);
    assertEq(_attestation1.schema, OP_SCHEMA_638);
    assertEq(_attestation2.schema, OP_SCHEMA_638);
    assertEq(_attestation3.schema, OP_SCHEMA_638);
  }

  /// @dev test that the attestation is pulling the correct attributes from the onchain attestation
  function test_validateAttestationAttributesAgainstOnchainAttestation() public view {
    assertEq(_attestation0.uid, referenceAttestation0.uid);
    assertEq(_attestation0.schema, referenceAttestation0.schema);
    assertEq(_attestation0.time, referenceAttestation0.time);
    assertEq(_attestation0.expirationTime, referenceAttestation0.expirationTime);
    assertEq(_attestation0.revocationTime, referenceAttestation0.revocationTime);
    assertEq(_attestation0.refUID, referenceAttestation0.refUID);
    assertEq(_attestation0.recipient, referenceAttestation0.recipient);
    assertEq(_attestation0.attester, referenceAttestation0.attester);
    assertEq(_attestation0.revocable, referenceAttestation0.revocable);
  }

  /// @dev test that the attestation contains the expected attributes
  function test_validateAttestationAttributesAgainstExpectedValues() public view {
    /// @dev check expected values
    assertEq(_attestation0.uid, OP_SCHEMA_UID_0);
    assertEq(_attestation0.schema, OP_SCHEMA_638);
    assertEq(_attestation0.attester, OP_FOUNDATION_ATTESTER_1);
    /// @dev check non-zero values
    assertNotEq(_attestation0.time, 0);
    assertNotEq(_attestation0.recipient, address(0));
  }

  /// @dev test that the attestation data is valid
  function test_validateAttestationData() public view {
    (bytes32 _projectRefId,) = abi.decode(_attestation0.data, (bytes32, bytes));
    assertTrue(eas.isAttestationValid(_projectRefId));
  }
}
