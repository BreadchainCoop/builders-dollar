// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IEAS} from '@eas/IEAS.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import {ISchemaValidator} from 'interfaces/ISchemaValidator.sol';

contract SchemaValidatorBase is ISchemaValidator {
  /// @inheritdoc ISchemaValidator
  bytes32 public immutable SCHEMA;
  /// @inheritdoc ISchemaValidator
  IBuildersManager public immutable BUILDERS_MANAGER;
  /// @inheritdoc ISchemaValidator
  IEAS public immutable EAS;

  /**
   * @notice Initialize the SchemaValidator contract
   * @param _schema The schema to validate
   * @param _buildersManager The BuildersManager contract
   */
  constructor(bytes32 _schema, address _buildersManager) {
    SCHEMA = _schema;
    BUILDERS_MANAGER = IBuildersManager(_buildersManager);
    EAS = BUILDERS_MANAGER.EAS();

    if (EAS.getSchemaRegistry().getSchema(SCHEMA).uid != SCHEMA) revert InvalidSchema();
  }

  /// @inheritdoc ISchemaValidator
  function validateWithSchema(bytes32, address) external virtual returns (bool _verified) {
    /// @dev This function needs to be defined for the interface; use override for logic implementation
    _verified = false;
  }

  /// @inheritdoc ISchemaValidator
  function validateWithSchema(bytes32) external virtual returns (bool _verified) {
    /// @dev This function needs to be defined for the interface; use override for logic implementation
    _verified = false;
  }
}
