// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation} from '@eas/Common.sol';
import {SchemaValidatorBase} from 'contracts/schemas/SchemaValidatorBase.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';

contract SchemaValidator638 is SchemaValidatorBase {
  /// @notice see SchemaValidatorBase
  constructor(bytes32 _schema, address _buildersManager) SchemaValidatorBase(_schema, _buildersManager) {}

  /// @inheritdoc SchemaValidatorBase
  function validateWithSchema(bytes32 _uid) external view override returns (bool _verified, address _recipient) {
    Attestation memory _attestation = EAS.getAttestation(_uid);
    (bytes32 _projectRefId,) = abi.decode(_attestation.data, (bytes32, bytes));
    IBuildersManager.BuilderManagerSettings memory _settings = BUILDERS_MANAGER.settings();
    _recipient = _attestation.recipient;

    if (_recipient == address(0)) return (false, _recipient);
    if (!BUILDERS_MANAGER.optimismFoundationAttester(_attestation.attester)) return (false, _recipient);
    if (_attestation.time < _settings.currentSeasonExpiry - _settings.seasonDuration) return (false, _recipient);
    if (!EAS.isAttestationValid(_projectRefId)) return (false, _recipient);

    _verified = true;
  }
}
