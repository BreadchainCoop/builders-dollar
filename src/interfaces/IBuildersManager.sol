// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {IEAS} from '@eas/IEAS.sol';
import {OffchainAttestation} from 'interfaces/IEasExtensions.sol';

/**
 * @title BuildersManager Contract
 * @author Breadchain
 * @notice This contract manages the OP Foundation project voting and yield distribution
 */
interface IBuildersManager {
  /*///////////////////////////////////////////////////////////////
                            DATA
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Builder Manager settings
   * @param cycleLength The yield distribution cycle length
   * @param lastClaimedTimestamp The timestamp for the last time yield was claimed
   * @param currentSeasonExpiry The timestamp for the current season expiry
   * @param seasonDuration The duration of a season
   * @param minVouches The minimum number of vouches required for a project to receive yield
   * @param optimismFoundationAttesters The list of attesting addresses for the OP Foundation
   */
  struct BuilderManagerSettings {
    uint64 cycleLength;
    uint64 lastClaimedTimestamp;
    uint64 currentSeasonExpiry;
    uint256 seasonDuration;
    uint256 minVouches;
    address[] optimismFoundationAttesters;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emitted when a project is validated
   * @param _approvalAttestation The attestation hash
   * @param _recipient The recipient of the project
   */
  event ProjectValidated(bytes32 indexed _approvalAttestation, address indexed _recipient);

  /**
   * @notice Emitted when a voter is validated
   * @param _claimer The caller claiming the voter validation
   * @param _identityAttestation The identity attestation hash
   */
  event VoterValidated(address indexed _claimer, bytes32 indexed _identityAttestation);

  /**
   * @notice The event emitted when yield is distributed
   * @param _yield The yield amount per project
   * @param _projects The list of projects that received yield
   */
  event YieldDistributed(uint256 _yield, address[] _projects);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Throws when the parameter is already set
  /// @param _attester The attester address
  error AlreadyUpdated(address _attester);
  /// @notice Throws when the project or voter is already verified
  error AlreadyVerified();
  /// @notice Throws when the voter has already vouched for a project
  error AlreadyVouched();
  /// @notice Throws when the project is not in the current projects list
  error CycleNotReady();
  /// @notice Throws when the identification-attestation is required
  error IdAttestationRequired();
  /// @notice Throws when the identification-attestation is invalid
  error InvalidIdAttestation();
  /// @notice Throws when the project-attestation is invalid
  error InvalidProjectAttestation();
  /// @notice Throws when the array length is invalid
  error InvalidLength();
  /// @notice Throws when the bytes32 parameter is incorrect
  /// @param _param The invalid parameter
  error InvalidParamBytes32(bytes32 _param);
  /// @notice Throws when the settings are not set at initialization
  error SettingsNotSet();
  /// @notice Throws when the project is not found
  error YieldNoProjects();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Initialize the BuildersManager contract
   * @param _token The BuildersDollar token address
   * @param _eas The Ethereum-Attestation-Service (EAS) contract address
   * @param _name The human-readable name of the signing domain (i.e. the name the protocol)
   * @param _version The current major version of the signing domain
   * @param _params The BuilderManager parameters
   */
  function initialize(
    address _token,
    address _eas,
    string memory _name,
    string memory _version,
    BuilderManagerSettings memory _params
  ) external;

  /**
   * @notice Verify a project with an off-chain attestation and vouch for a project
   * @param _offchainProjectAttestation The attestation of the project
   */
  function vouch(OffchainAttestation calldata _offchainProjectAttestation) external;

  /**
   * @notice Verify a project with an off-chain attestation and vouch for a project
   * @param _offchainProjectAttestation The attestation of the project
   * @param _identityAttestation The attestation of the voucher's identity
   */
  function vouch(OffchainAttestation calldata _offchainProjectAttestation, bytes32 _identityAttestation) external;

  /**
   * @notice Vouch for a project
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   */
  function vouch(bytes32 _projectApprovalAttestation) external;

  /**
   * @notice Vouch for a project and validate the voucher's identity
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   * @param _identityAttestation The attestation hash of the voucher's identity
   */
  function vouch(bytes32 _projectApprovalAttestation, bytes32 _identityAttestation) external;

  /**
   * @notice Distribute the yield to the current projects in the cycle
   */
  function distributeYield() external;

  /**
   * @notice Modify the BuilderManager parameters
   * @dev Access Control: onlyOwner
   * @param _param The parameter to modify
   * @param _value The new value for the parameter
   */
  function modifyParams(bytes32 _param, uint256 _value) external;

  /**
   * @notice Update the status of multiple OP Foundation attesters
   * @dev Access Control: onlyOwner
   * @param _attestersToUpdate The list of OP Foundation attesters to modify
   * @param _statuses The list of statuses to set for the attesters (true = add, false = remove)
   */
  function batchUpdateOpFoundationAttesters(address[] memory _attestersToUpdate, bool[] memory _statuses) external;

  /**
   * @notice Update the status of a OP Foundation attester
   * @dev Access Control: onlyOwner
   * @param _attester The OP Foundation attester to modify
   * @param _status The status to set for the attester (true = add, false = remove)
   */
  function updateOpFoundationAttester(address _attester, bool _status) external;

  /*///////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Get the Builder's Dollar Token
   * @dev This variable functionally-immutable and set during intialization
   * @return _builderToken The Builder Token
   */
  // solhint-disable-next-line func-name-mixedcase
  function TOKEN() external view returns (BuildersDollar _builderToken);

  /**
   * @notice Get the Ethereum-Attestation-Service (EAS) contract
   * @dev This variable functionally-immutable and set during intialization
   * @return _eas The EAS contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function EAS() external view returns (IEAS _eas);

  /**
   * @notice Check if the attester is an Optimism Foundation Attester
   * @param _attester The attester
   * @return _isEligible True if the attester is an Optimism Foundation Attester
   */
  function optimismFoundationAttester(address _attester) external view returns (bool _isEligible);

  /**
   * @notice Check if the voter is eligible and vouched
   * @param _voter The voter
   * @return _isEligibleAndVouched True if the voter is eligible and vouched
   */
  function eligibleVoter(address _voter) external view returns (bool _isEligibleAndVouched);

  /**
   * @notice Check if the project is eligible
   * @param _projectAttestation The project attestation hash
   * @dev hash is produced by:
   * _hashTypedDataV4(
   *   keccak256(
   *     abi.encode(
   *       _VERSION1_ATTEST_TYPEHASH,
   *       _VERSION1,
   *       _attestation.schema,
   *       _attestation.recipient,
   *       _attestation.time,
   *       _attestation.expirationTime,
   *       _attestation.revocable,
   *       _attestation.refUID,
   *       keccak256(_attestation.data)
   *     )
   *   )
   * @return _project The project
   */
  function eligibleProject(bytes32 _projectAttestation) external view returns (address _project);

  /**
   * @notice Get the expiry for a project
   * @param _project The project
   * @return _expiry The expiration timestamp for the project
   */
  function projectToExpiry(address _project) external view returns (uint256 _expiry);

  /**
   * @notice Get the total vouches for a project
   * @param _project The project
   * @return _totalVouches The total vouches for the project
   */
  function projectToVouches(address _project) external view returns (uint256 _totalVouches);

  /**
   * @notice Check if the user has vouched for the project
   * @param _voter The voter
   * @param _attestHash The attestation hash
   * @return _vouched True if the user has vouched for the project
   */
  function voterToProjectVouch(address _voter, bytes32 _attestHash) external view returns (bool _vouched);

  /**
   * @notice Get the current BuilderManager settings
   * @return __settings The BuilderManager settings
   */
  function settings() external view returns (BuilderManagerSettings memory __settings);

  /**
   * @notice Get the current projects
   * @return _projects The list of current projects
   */
  function currentProjects() external view returns (address[] memory _projects);

  /**
   * @notice Get the OP Foundation Attesters
   * @return _optimismFoundationAttesters The list of OP Foundation Attesters
   */
  function optimismFoundationAttesters() external view returns (address[] memory _optimismFoundationAttesters);
}
