// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {SchemaValidatorBase} from 'contracts/schemas/SchemaValidatorBase.sol';

contract SchemaValidator599 is SchemaValidatorBase {
  /// @notice Accepted voter type: Guest
  bytes32 internal constant _GUEST = 'Guest';
  /// @notice Accepted voter type: Citizen
  bytes32 internal constant _CITIZEN = 'Citizen';

  /// @notice see SchemaValidatorBase
  constructor(bytes32 _schema, address _buildersManager) SchemaValidatorBase(_schema, _buildersManager) {}

  /// @inheritdoc SchemaValidatorBase
  function validateWithSchema(bytes32 _uid, address _claimer) external view override returns (bool _verified) {
    Attestation memory _attestation = EAS.getAttestation(_uid);
    (,, string memory _voterType,,) = abi.decode(_attestation.data, (uint256, string, string, string, string));
    bytes32 _voterTypeBytes = bytes32(bytes(_voterType));

    if (_attestation.uid == EMPTY_UID) return false;
    if (_attestation.recipient != _claimer) return false;
    if (_voterTypeBytes != _GUEST && _voterTypeBytes != _CITIZEN) return false;

    _verified = true;
  }
}
