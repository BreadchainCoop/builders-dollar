// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {Attestation} from '@eas/Common.sol';
import {IEAS} from '@eas/IEAS.sol';
import {Ownable2StepUpgradeable} from '@oz-upgradeable/access/Ownable2StepUpgradeable.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';

contract BuildersManager is Ownable2StepUpgradeable, IBuildersManager {
  /// @notice Hash used to varify Grantee status
  bytes32 private constant _GRANTEE_HASH = keccak256(bytes('Grantee'));
  /// @notice Hash used to varify Application Approved status
  bytes32 private constant _APPLICATION_APPROVED_HASH = keccak256(bytes('Application Approved'));

  // --- Registry ---

  /// @inheritdoc IBuildersManager
  BuildersDollar public token;
  /// @inheritdoc IBuildersManager
  IEAS public eas;

  // --- Data ---

  /// @notice See params
  BuilderManagerParams internal _params;

  /// @inheritdoc IBuildersManager
  mapping(address _voter => bool _isEligibleAndVouched) public eligibleVoter;
  /// @inheritdoc IBuildersManager
  mapping(address _project => uint256 _expiry) public projectToExpiry;
  /// @inheritdoc IBuildersManager
  mapping(bytes32 _attestHash => address _project) public eligibleProject;
  /// @inheritdoc IBuildersManager
  mapping(address _project => uint256 _totalVouches) public projectToVouches;
  /// @inheritdoc IBuildersManager
  mapping(address _voter => mapping(bytes32 _attestHash => bool _vouched)) public userToProjectVouch;

  /// @notice See currentProjects
  address[] internal _currentProjects;

  // --- Modifiers ---

  /**
   * @notice Modifier to check if the user has already vouched for the project
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   */
  modifier vouched(bytes32 _projectApprovalAttestation) {
    if (userToProjectVouch[msg.sender][_projectApprovalAttestation]) revert AlreadyVouched();
    _;
  }

  // --- Initializer ---

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  // TODO: add param enforcement modifiers
  /// @inheritdoc IBuildersManager
  function initialize(address _token, address _eas, BuilderManagerParams memory __params) external initializer {
    token = BuildersDollar(_token);
    eas = IEAS(_eas);
    _params = __params;
  }

  // --- External Methods ---

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectApprovalAttestation) external vouched(_projectApprovalAttestation) {
    if (!eligibleVoter[msg.sender]) revert IdAttestationRequired();
    _vouch(_projectApprovalAttestation);
  }

  /// @inheritdoc IBuildersManager
  function vouch(
    bytes32 _projectApprovalAttestation,
    bytes32 _identityAttestation
  ) external vouched(_projectApprovalAttestation) {
    if (!eligibleVoter[msg.sender]) {
      if (!_validateOptimismVoter(_identityAttestation, msg.sender)) revert InvalidIdAttestation();
    }
    _vouch(_projectApprovalAttestation);
  }

  /// @inheritdoc IBuildersManager
  function ejectProject(address _project) external {
    // TODO: Add security - who can eject a project?
    _ejectProject(_project);
  }

  /// @inheritdoc IBuildersManager
  function distributeYield() external {
    uint256 _l = _currentProjects.length;
    if (_l == 0) revert YieldNoProjects();
    if (block.timestamp < _params.lastClaimedTimestamp + _params.cycleLength) revert YieldNotReady();
    _params.lastClaimedTimestamp = uint64(block.timestamp);

    for (uint256 _i; _i < _l; ++_i) {
      address _project = _currentProjects[_i];
      if (projectToExpiry[_project] > block.timestamp) _ejectProject(_project);
      else if (projectToVouches[_project] < _params.minVouches) _ejectProject(_project);
    }

    _l = _currentProjects.length;
    if (_l == 0) revert YieldNoProjects();

    uint256 _yield = token.yieldAccrued();
    token.claimYield(_yield);
    uint256 _yieldPerProject = ((_yield * _params.precision) / _l) / _params.precision;

    for (uint256 _i; _i < _l; ++_i) {
      token.transfer(_currentProjects[_i], _yieldPerProject);
    }
    emit YieldDistributed(_yieldPerProject, _currentProjects);
  }

  /// @inheritdoc IBuildersManager
  function params() external view returns (BuilderManagerParams memory __params) {
    __params = _params;
  }

  /// @inheritdoc IBuildersManager
  function currentProjects() external view returns (address[] memory _projects) {
    _projects = _currentProjects;
  }

  /// @inheritdoc IBuildersManager
  function optimismFoundationAttestors() external view returns (address[] memory _opAttestors) {
    _opAttestors = _params.optimismFoundationAttestors;
  }

  // --- Public Methods ---

  // TODO: Does this need to be public or can it be internal?
  /// @inheritdoc IBuildersManager
  function validateProject(bytes32 _approvalAttestation) public virtual returns (bool _valid) {
    if (isValidProject(_approvalAttestation)) revert AlreadyValid();

    Attestation memory _attestation = eas.getAttestation(_approvalAttestation);
    if (_attestation.uid == bytes32(0)) revert AttestationNotFound();
    if (!_isValidAttestor(_attestation.attester)) revert InvalidOpAttestor();
    if (_attestation.time < _params.currentSeasonExpiry - _params.seasonDuration) revert NotInSeason();

    (string memory _param1,,,, string memory _param5) =
      abi.decode(_attestation.data, (string, string, string, string, string));

    if (keccak256(bytes(_param1)) != _GRANTEE_HASH) revert InvalidParam(bytes(_param1));
    if (keccak256(bytes(_param5)) != _APPLICATION_APPROVED_HASH) revert InvalidParam(bytes(_param5));

    address _project = _attestation.recipient;
    _currentProjects.push(_project);
    eligibleProject[_approvalAttestation] = _project;
    projectToExpiry[_project] = _params.currentSeasonExpiry;

    emit ProjectValidated(_approvalAttestation, _project);
    _valid = true;
  }

  /// @inheritdoc IBuildersManager
  function isValidProject(bytes32 _approvalAttestation) public view returns (bool _valid) {
    if (eligibleProject[_approvalAttestation] != address(0)) _valid = true;
  }

  // --- Internal Utilities ---

  /**
   * @notice Check if the project has been previously vouched for
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   */
  function _vouch(bytes32 _projectApprovalAttestation) internal {
    if (eligibleProject[_projectApprovalAttestation] == address(0)) {
      validateProject(_projectApprovalAttestation);
    }
  }

  /**
   * @notice Function to validate the voucher's identity
   * @param _identityAttestation The attestation hash of the voucher's identity
   * @param _claimer The address of the voucher
   * @return _valid True if the voter is elegible
   */
  function _validateOptimismVoter(bytes32 _identityAttestation, address _claimer) internal returns (bool _valid) {
    Attestation memory _attestation = eas.getAttestation(_identityAttestation);
    if (_attestation.uid == bytes32(0)) revert AttestationNotFound();
    if (!_isValidAttestor(_attestation.attester)) revert InvalidOpAttestor();
    if (_attestation.recipient != _claimer) revert NotRecipient();

    (uint256 farcasterID,,,,) = abi.decode(_attestation.data, (uint256, string, string, string, string));

    eligibleVoter[_claimer] = true;
    emit VoterValidated(_claimer, farcasterID);
    _valid = true;
  }

  /**
   * @notice Remove project from the current projects list and zero out the vouches
   * @param _project The project
   */
  function _ejectProject(address _project) internal {
    projectToExpiry[_project] = 0;
    projectToVouches[_project] = 0;

    uint256 _l = _currentProjects.length;
    for (uint256 _i; _i < _l; _i++) {
      if (_currentProjects[_i] == _project) {
        _currentProjects[_i] = _currentProjects[_l - 1];
        _currentProjects.pop();
      }
    }
  }

  /**
   * @notice Check if the attester is one of the Optimism Foundation attestors
   * @param _attester The address of the attester
   * @return _isValid True if the attester is one of the Optimism Foundation attestors
   */
  function _isValidAttestor(address _attester) internal view returns (bool _isValid) {
    uint256 _l = _params.optimismFoundationAttestors.length;
    for (uint256 _i; _i < _l; _i++) {
      if (_attester == _params.optimismFoundationAttestors[_i]) _isValid = true;
    }
  }
}
