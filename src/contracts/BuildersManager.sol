// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {Attestation} from '@eas/Common.sol';
import {IEAS} from '@eas/IEAS.sol';
import {Ownable2StepUpgradeable} from '@oz-upgradeable/access/Ownable2StepUpgradeable.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';

contract BuildersManager is Ownable2StepUpgradeable, IBuildersManager {
  /// @notice The mutliplier used for fixed-point division
  uint256 private constant _PRECISION = 1e18;
  /// @notice Hash used to varify Grantee status
  bytes32 private constant _GRANTEE_HASH = keccak256(bytes('Grantee'));
  /// @notice Hash used to varify Application Approved status
  bytes32 private constant _APPLICATION_APPROVED_HASH = keccak256(bytes('Application Approved'));

  // --- Registry ---

  /// @inheritdoc IBuildersManager
  // solhint-disable-next-line
  BuildersDollar public TOKEN;
  /// @inheritdoc IBuildersManager
  // solhint-disable-next-line
  IEAS public EAS;

  // --- Data ---

  /// @notice See params @IBuildersManager
  BuilderManagerParams internal _params;

  /// @inheritdoc IBuildersManager
  mapping(address _attester => bool _isEligible) public optimismFoundationAttester;
  /// @inheritdoc IBuildersManager
  mapping(address _voter => bool _isEligibleAndVouched) public eligibleVoter;
  /// @inheritdoc IBuildersManager
  mapping(bytes32 _attestHash => address _project) public eligibleProject;
  /// @inheritdoc IBuildersManager
  mapping(address _project => uint256 _expiry) public projectToExpiry;
  /// @inheritdoc IBuildersManager
  mapping(address _project => uint256 _totalVouches) public projectToVouches;
  /// @inheritdoc IBuildersManager
  mapping(address _voter => mapping(bytes32 _attestHash => bool _vouched)) public voterToProjectVouch;

  /// @notice See currentProjects @IBuildersManager
  address[] internal _currentProjects;

  // --- Modifiers ---

  /**
   * @notice Modifier to check if the user has already vouched for the project
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   */
  modifier vouched(bytes32 _projectApprovalAttestation) {
    if (voterToProjectVouch[msg.sender][_projectApprovalAttestation]) revert AlreadyVouched();
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
    TOKEN = BuildersDollar(_token);
    EAS = IEAS(_eas);
    _params = __params;

    uint256 _l = _params.optimismFoundationAttesters.length;
    for (uint256 _i; _i < _l; ++_i) {
      optimismFoundationAttester[_params.optimismFoundationAttesters[_i]] = true;
    }
  }

  // --- External Methods ---

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectApprovalAttestation) external vouched(_projectApprovalAttestation) {
    if (!eligibleVoter[msg.sender]) revert IdAttestationRequired();
    _vouch(_projectApprovalAttestation, msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function vouch(
    bytes32 _projectApprovalAttestation,
    bytes32 _identityAttestation
  ) external vouched(_projectApprovalAttestation) {
    if (!eligibleVoter[msg.sender]) {
      if (!_validateOptimismVoter(_identityAttestation, msg.sender)) revert InvalidIdAttestation();
    }
    _vouch(_projectApprovalAttestation, msg.sender);
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

    uint256 _yield = TOKEN.yieldAccrued();
    TOKEN.claimYield(_yield);
    uint256 _yieldPerProject = ((_yield * _PRECISION) / _l) / _PRECISION;

    for (uint256 _i; _i < _l; ++_i) {
      TOKEN.transfer(_currentProjects[_i], _yieldPerProject);
    }
    emit YieldDistributed(_yieldPerProject, _currentProjects);
  }

  /// @inheritdoc IBuildersManager
  function ejectProject(address _project) external onlyOwner {
    _ejectProject(_project);
  }

  /// @inheritdoc IBuildersManager
  function modifyParams(bytes32 _param, uint256 _value) external onlyOwner {
    _modifyParams(_param, _value);
  }

  /// @inheritdoc IBuildersManager
  function updateOpFoundationAttester(address _attester, bool _status) external onlyOwner {
    _modifyOpFoundationAttester(_attester, _status);
  }

  /// @inheritdoc IBuildersManager
  function batchUpdateOpFoundationAttesters(
    address[] memory _attestersToUpdate,
    bool[] memory _statuses
  ) external onlyOwner {
    uint256 _l = _attestersToUpdate.length;
    if (_l != _statuses.length) revert InvalidLength();

    for (uint256 _i; _i < _l; _i++) {
      _modifyOpFoundationAttester(_attestersToUpdate[_i], _statuses[_i]);
    }
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
  function optimismFoundationAttesters() external view returns (address[] memory _opAttesters) {
    _opAttesters = _params.optimismFoundationAttesters;
  }

  // --- Public Methods ---

  /// @inheritdoc IBuildersManager
  function isValidProject(bytes32 _approvalAttestation) public view returns (bool _valid) {
    if (eligibleProject[_approvalAttestation] != address(0)) _valid = true;
  }

  // --- Internal Utilities ---

  /**
   * @notice Compare the attestation hash of the project's approval and validate the project
   * @param _projectApprovalAttestation The attestation hash of the project's approval
   * @param _voter The address of the voucher
   */
  function _vouch(bytes32 _projectApprovalAttestation, address _voter) internal {
    if (eligibleProject[_projectApprovalAttestation] == address(0)) {
      _validateProject(_projectApprovalAttestation);
    }

    if (eligibleProject[_projectApprovalAttestation] == address(0)) revert ProjectNotEligible();
    voterToProjectVouch[_voter][_projectApprovalAttestation] = true;
  }

  /**
   * @notice Function to validate the voucher's identity
   * @param _identityAttestation The attestation hash of the voucher's identity
   * @param _claimer The address of the voucher
   * @return _valid True if the voter is elegible
   */
  function _validateOptimismVoter(bytes32 _identityAttestation, address _claimer) internal returns (bool _valid) {
    Attestation memory _attestation = EAS.getAttestation(_identityAttestation);
    if (_attestation.uid == bytes32(0)) revert AttestationNotFound();
    if (!optimismFoundationAttester[_attestation.attester]) revert InvalidOpAttester();
    if (_attestation.recipient != _claimer) revert NotRecipient();

    (uint256 farcasterID,,,,) = abi.decode(_attestation.data, (uint256, string, string, string, string));

    eligibleVoter[_claimer] = true;
    emit VoterValidated(_claimer, farcasterID);
    _valid = true;
  }

  /**
   * @notice Function to validate the project's attestation
   * @param _approvalAttestation The attestation hash of the project's approval
   * @return _valid True if the project is valid
   */
  function _validateProject(bytes32 _approvalAttestation) internal returns (bool _valid) {
    if (isValidProject(_approvalAttestation)) revert AlreadyValid();

    Attestation memory _attestation = EAS.getAttestation(_approvalAttestation);
    if (_attestation.uid == bytes32(0)) revert AttestationNotFound();
    if (!optimismFoundationAttester[_attestation.attester]) revert InvalidOpAttester();
    if (_attestation.time < _params.currentSeasonExpiry - _params.seasonDuration) revert NotInSeason();

    (string memory _param1,,,, string memory _param5) =
      abi.decode(_attestation.data, (string, string, string, string, string));

    if (keccak256(bytes(_param1)) != _GRANTEE_HASH) revert InvalidParamBytes(bytes(_param1));
    if (keccak256(bytes(_param5)) != _APPLICATION_APPROVED_HASH) revert InvalidParamBytes(bytes(_param5));

    address _project = _attestation.recipient;
    _currentProjects.push(_project);
    eligibleProject[_approvalAttestation] = _project;
    projectToExpiry[_project] = _params.currentSeasonExpiry;

    emit ProjectValidated(_approvalAttestation, _project);
    _valid = true;
  }

  /**
   * @notice See ejectProject @IBuildersManager
   * @param _project The project to eject
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
   * @notice See modifyParams @IBuildersManager
   * @param _param The parameter to modify
   * @param _value The new value
   */
  function _modifyParams(bytes32 _param, uint256 _value) internal {
    if (_param == 'cycleLength') _params.cycleLength = uint64(_value);
    else if (_param == 'lastClaimedTimestamp') _params.lastClaimedTimestamp = uint64(_value);
    else if (_param == 'currentSeasonExpiry') _params.currentSeasonExpiry = uint64(_value);
    else if (_param == 'seasonDuration') _params.seasonDuration = _value;
    else if (_param == 'minVouches') _params.minVouches = _value;
    else revert InvalidParamBytes32(_param);
  }

  /**
   * @notice See updateOpFoundationAttester @IBuildersManager
   * @param _attester The attester address
   * @param _status The attester status
   */
  function _modifyOpFoundationAttester(address _attester, bool _status) internal {
    bool _currentStatus = optimismFoundationAttester[_attester];
    if (_currentStatus == _status) revert AlreadyUpdated(_attester);

    optimismFoundationAttester[_attester] = _status;

    if (_status) {
      _params.optimismFoundationAttesters.push(_attester);
    } else {
      uint256 _l = _params.optimismFoundationAttesters.length;
      for (uint256 _i; _i < _l; _i++) {
        if (_params.optimismFoundationAttesters[_i] == _attester) {
          _params.optimismFoundationAttesters[_i] = _params.optimismFoundationAttesters[_l - 1];
          _params.optimismFoundationAttesters.pop();
        }
      }
    }
  }
}
