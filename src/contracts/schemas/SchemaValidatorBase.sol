// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IEAS} from '@eas/IEAS.sol';
import {IBuilderManager} from 'interfaces/IBuilderManager.sol';
import {ISchemaValidator} from 'interfaces/ISchemaValidator.sol';

contract SchemaValidatorBase is ISchemaValidator {
  /// @inheritdoc ISchemaValidator
  bytes32 public immutable SCHEMA;
  /// @inheritdoc ISchemaValidator
  IBuilderManager public immutable BUILDERS_MANAGER;
  /// @inheritdoc ISchemaValidator
  IEAS public immutable EAS;

  /**
   * @notice Initialize the SchemaValidator contract
   * @param _schema The schema to validate
   * @param _buildersManager The BuilderManager contract
   */
  constructor(bytes32 _schema, address _buildersManager) {
    SCHEMA = _schema;
    BUILDERS_MANAGER = IBuilderManager(_buildersManager);
    EAS = BUILDERS_MANAGER.EAS();

    if (EAS.getSchemaRegistry().getSchema(SCHEMA).uid != SCHEMA) revert InvalidSchema();
  }

  /// @inheritdoc ISchemaValidator
  function validateWithSchema(bytes32, address) external view virtual returns (bool _verified) {
    /// @dev This function needs to be defined for the interface; use override for logic implementation
    _verified = false;
  }

  /// @inheritdoc ISchemaValidator
  function validateWithSchema(bytes32) external view virtual returns (bool _verified, address _recipient) {
    /// @dev This function needs to be defined for the interface; use override for logic implementation
    _recipient = address(0);
    _verified = false;
  }
}
