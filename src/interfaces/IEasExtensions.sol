// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Signature} from '@eas/Common.sol';

/**
 * @notice A struct representing an offchain attestation request
 * @param version The version of the attestation
 * @param attester The attester of the attestation
 * @param schema The unique identifier of the schema
 * @param recipient The recipient of the attestation
 * @param time The time when the attestation was signed
 * @param expirationTime The time when the attestation expires (Unix timestamp)
 * @param revocable Whether the attestation is revocable
 * @param refUID The UID of the related attestation
 * @param data Custom attestation data
 * @param signature The ECDSA signature data
 */
struct OffchainAttestation {
  uint16 version;
  address attester;
  bytes32 schema;
  address recipient;
  uint64 time;
  uint64 expirationTime;
  bool revocable;
  bytes32 refUID;
  bytes data;
  Signature signature;
}
