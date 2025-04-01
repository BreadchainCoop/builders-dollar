// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IEAS} from '@eas/IEAS.sol';
import {IBuilderManager} from 'interfaces/IBuilderManager.sol';

/**
 * @title ISchemaValidator
 * @notice Interface for the SchemaValidatorBase contract for use with the BuilderManager contract
 */
interface ISchemaValidator {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when the schema does not exist in the EAS
  error InvalidSchema();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Validate with a specific schema for 2 params
   * @param _uid The uid of the attestation
   * @param _caller The address of the caller
   * @return _verified True if the voter is verified
   */
  function validateWithSchema(bytes32 _uid, address _caller) external returns (bool _verified);

  /**
   * @notice Validate with a specific schema for 1 param
   * @param _uid The uid of the attestation
   * @return _verified True if the project is verified
   */
  function validateWithSchema(bytes32 _uid) external returns (bool _verified, address _recipient);

  /*///////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Get the schema
   * @return _schema The schema
   */
  // solhint-disable-next-line func-name-mixedcase
  function SCHEMA() external view returns (bytes32 _schema);

  /**
   * @notice Get the BuilderManager contract
   * @return _buildersManager The BuilderManager contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function BUILDERS_MANAGER() external view returns (IBuilderManager _buildersManager);

  /**
   * @notice Get the Ethereum-Attestation-Service (EAS) contract
   * @return _eas The EAS contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function EAS() external view returns (IEAS _eas);
}
