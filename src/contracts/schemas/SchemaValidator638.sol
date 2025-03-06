// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {SchemaValidatorBase} from 'contracts/schemas/SchemaValidatorBase.sol';

contract SchemaValidator638 is SchemaValidatorBase {
  /// @notice see SchemaValidatorBase
  constructor(bytes32 _schema, address _buildersManager) SchemaValidatorBase(_schema, _buildersManager) {}

  /// @inheritdoc SchemaValidatorBase
  function validateWithSchema(bytes32 _uid) external override returns (bool _verified) {}
}
