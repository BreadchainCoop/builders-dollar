// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {IEAS} from '@eas/IEAS.sol';

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
   * @notice Builder Manager Parameters
   * @param cycleLength The yield distribution cycle length
   * @param lastClaimedTimestamp The timestamp for the last time yield was claimed
   * @param currentSeasonExpiry The timestamp for the current season expiry
   * @param seasonDuration The duration of a season
   * @param minVouches The minimum number of vouches required for a project to receive yield
   * @param optimismFoundationAttesters The list of attesting addresses for the OP Foundation
   */
  struct BuilderManagerParams {
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
   * @param _farcasterID The Farcaster ID to prevent sybil attacks
   */
  event VoterValidated(address indexed _claimer, uint256 indexed _farcasterID);

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
  /// @notice Throws when the project is already valid
  error AlreadyValid();
  /// @notice Throws when the voter is already vouched
  error AlreadyVouched();
  /// @notice Throws when the attestation is not found
  error AttestationNotFound();
  /// @notice Throws when the identification-attestation is required
  error IdAttestationRequired();
  /// @notice Throws when the identification-attestation is invalid
  error InvalidIdAttestation();
  /// @notice Throws when the array length is invalid
  error InvalidLength();
  /// @notice Throws when the attester is not in the OP Foundation list
  error InvalidOpAttester();
  /// @notice Throws when the bytes32 parameter is incorrect
  /// @param _param The invalid parameter
  error InvalidParamBytes32(bytes32 _param);
  /// @notice Throws when the bytes parameter is incorrect
  /// @param _param The invalid parameter
  error InvalidParamBytes(bytes _param);
  /// @notice Throws when the project is not in season
  error NotInSeason();
  /// @notice Throws when the project is not eligible
  error NotRecipient();
  /// @notice Throws when the project is not eligible
  error ProjectNotEligible();
  /// @notice Throws when the project is not found
  error YieldNoProjects();
  /// @notice Throws when the project is not in the current projects list
  error YieldNotReady();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Initialize the BuildersManager contract
   * @param _token The BuildersDollar token address
   * @param _eas The Ethereum-Attestation-Service (EAS) contract address
   * @param _params The BuilderManager parameters
   */
  function initialize(address _token, address _eas, BuilderManagerParams memory _params) external;

  /**
   * @notice Vouch for a project
   * @dev Scenario 1 & 3: Voucher has already vouched
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   */
  function vouch(bytes32 _projectApprovalAttestation) external;

  /**
   * @notice Vouch for a project and validate the voucher's identity
   * @dev Scenario 2 & 4: Voucher has not vouched yet and needs to validate their identity
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   * @param _identityAttestation The attestation hash of the voucher's identity
   */
  function vouch(bytes32 _projectApprovalAttestation, bytes32 _identityAttestation) external;

  /**
   * @notice Distribute the yield to the current projects in the cycle
   */
  function distributeYield() external;

  /**
   * @notice Remove project from the current projects list and zero out the vouches
   * @param _project The project
   */
  function ejectProject(address _project) external;

  /**
   * @notice Modify the BuilderManager parameters
   * @param _param The parameter to modify
   * @param _value The new value for the parameter
   */
  function modifyParams(bytes32 _param, uint256 _value) external;

  /**
   * @notice Update the status of multiple OP Foundation attesters
   * @param _attestersToUpdate The list of OP Foundation attesters to modify
   * @param _actions The list of actions to take for the attesters (true = add, false = remove)
   */
  function batchUpdateOpFoundationAttesters(address[] memory _attestersToUpdate, bool[] memory _actions) external;

  /**
   * @notice Update the status of a OP Foundation attester
   * @param _attester The OP Foundation attester to modify
   * @param _valid The action to take for the attester (true = add, false = remove)
   */
  function updateOpFoundationAttester(address _attester, bool _valid) external;

  /*///////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Get the Builder's Dollar Token
   * @return _builderToken The Builder Token
   */
  function token() external view returns (BuildersDollar _builderToken);

  /**
   * @notice Get the Ethereum-Attestation-Service (EAS) contract
   * @return _eas The EAS contract
   */
  function eas() external view returns (IEAS _eas);

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
   * @param _attestHash The attestation hash
   * @return _project The project
   */
  function eligibleProject(bytes32 _attestHash) external view returns (address _project);

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
   * @notice Get the current BuilderManager parameters
   * @return __params The BuilderManager parameters
   */
  function params() external view returns (BuilderManagerParams memory __params);

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

  /**
   * @notice Check if the project is already eligible
   * @param _approvalAttestation The approval hash of the project
   * @return _valid True if the project is valid
   */
  function isValidProject(bytes32 _approvalAttestation) external view returns (bool _valid);
}
