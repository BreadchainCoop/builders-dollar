// SPDX-License-Identifier: PPL
pragma solidity 0.8.27;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {IEAS} from '@eas/IEAS.sol';
import {Ownable2StepUpgradeable} from '@oz-upgradeable/access/Ownable2StepUpgradeable.sol';
import {EIP712Upgradeable} from '@oz-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';

contract BuildersManager is EIP712Upgradeable, Ownable2StepUpgradeable, IBuildersManager {
  /// @notice The mutliplier used for fixed-point division
  uint256 private constant _PRECISION = 1e18;
  /// @inheritdoc IBuildersManager
  bytes32 public constant OP_SCHEMA_638 = 0x8aef6b9adab6252367588ad337f304da1c060cc3190f01d7b72c7e512b9bfb38;

  // --- Registry ---

  /// @inheritdoc IBuildersManager
  // solhint-disable-next-line
  BuildersDollar public TOKEN;
  /// @inheritdoc IBuildersManager
  // solhint-disable-next-line
  IEAS public EAS;

  // --- Data ---

  /// @notice See params @IBuildersManager
  BuilderManagerSettings internal _settings;

  /// @inheritdoc IBuildersManager
  mapping(address _attester => bool _isEligible) public optimismFoundationAttester;
  /// @inheritdoc IBuildersManager
  mapping(address _voter => bool _isEligibleAndVouched) public eligibleVoter;
  /// @inheritdoc IBuildersManager
  mapping(bytes32 _uid => address _project) public eligibleProject;
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
   * @notice Modifier to check if the project exists and if voter has already vouched for the project
   * @param _projectAttestation The attestation hash of the project
   * @param _caller The address of the caller
   */
  modifier eligible(bytes32 _projectAttestation, address _caller) {
    if (!eligibleVoter[_caller]) revert IdAttestationRequired();
    if (eligibleProject[_projectAttestation] == address(0)) revert InvalidProjectAttestation();
    if (voterToProjectVouch[_caller][_projectAttestation]) revert AlreadyVouched();
    _;
  }

  // --- Initializer ---

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IBuildersManager
  function initialize(
    address _token,
    address _eas,
    string memory _name,
    string memory _version,
    BuilderManagerSettings memory __settings
  ) external initializer {
    BuilderManagerSettings memory _s = __settings;
    if (_token == address(0) || _eas == address(0)) revert SettingsNotSet();
    if (bytes(_name).length == 0 || bytes(_version).length == 0) revert SettingsNotSet();
    if (!(_s.optimismFoundationAttesters.length > 0)) revert SettingsNotSet();
    if (_s.cycleLength * _s.currentSeasonExpiry * _s.seasonDuration * _s.minVouches == 0) revert SettingsNotSet();

    __Ownable_init(msg.sender);
    __EIP712_init(_name, _version);

    TOKEN = BuildersDollar(_token);
    EAS = IEAS(_eas);
    _settings = _s;

    uint256 _l = _s.optimismFoundationAttesters.length;
    for (uint256 _i; _i < _l; ++_i) {
      optimismFoundationAttester[_s.optimismFoundationAttesters[_i]] = true;
    }
  }

  // --- External Methods ---

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectAttestation) external {
    if (eligibleProject[_projectAttestation] == address(0)) {
      if (!_validateProject(_projectAttestation)) revert InvalidProjectAttestation();
    }
    _vouch(_projectAttestation, msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectAttestation, bytes32 _identityAttestation) external {
    if (eligibleProject[_projectAttestation] == address(0)) {
      if (!_validateProject(_projectAttestation)) revert InvalidProjectAttestation();
    }
    if (!_validateOptimismVoter(_identityAttestation, msg.sender)) revert InvalidIdAttestation();
    _vouch(_projectAttestation, msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function validateOptimismVoter(bytes32 _identityAttestation) external returns (bool _verified) {
    if (eligibleVoter[msg.sender]) _verified = true;
    else _verified = _validateOptimismVoter(_identityAttestation, msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function distributeYield() external {
    uint256 _l = _currentProjects.length;
    if (_l == 0) revert YieldNoProjects();
    if (block.timestamp < _settings.lastClaimedTimestamp + _settings.cycleLength) revert CycleNotReady();
    _settings.lastClaimedTimestamp = uint64(block.timestamp);

    for (uint256 _i; _i < _l;) {
      address _project = _currentProjects[_i];
      if (projectToExpiry[_project] < block.timestamp) _ejectProject(_project);
      unchecked {
        ++_i;
      }
    }
    _l = _currentProjects.length;
    if (_l == 0) revert YieldNoProjects();

    uint256 _yield = TOKEN.yieldAccrued();
    TOKEN.claimYield(_yield);
    uint256 _yieldPerProject = ((_yield * _PRECISION) / _l) / _PRECISION;

    for (uint256 _i; _i < _l;) {
      TOKEN.transfer(_currentProjects[_i], _yieldPerProject);
      unchecked {
        ++_i;
      }
    }
    emit YieldDistributed(_yieldPerProject, _currentProjects);
  }

  /// @inheritdoc IBuildersManager
  function modifyParams(bytes32 _param, uint256 _value) external onlyOwner {
    if (_value == 0) revert ZeroValue();
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
  function settings() external view returns (BuilderManagerSettings memory __settings) {
    __settings = _settings;
  }

  /// @inheritdoc IBuildersManager
  function currentProjects() external view returns (address[] memory _projects) {
    _projects = _currentProjects;
  }

  /// @inheritdoc IBuildersManager
  function optimismFoundationAttesters() external view returns (address[] memory _opAttesters) {
    _opAttesters = _settings.optimismFoundationAttesters;
  }

  // --- Internal Utilities ---

  /**
   * @notice Internal function to vouch for a project
   * @param _projectAttestation The attestation hash of the project
   * @param _caller The address of the caller
   */
  function _vouch(bytes32 _projectAttestation, address _caller) internal eligible(_projectAttestation, _caller) {
    voterToProjectVouch[_caller][_projectAttestation] = true;
    address _project = eligibleProject[_projectAttestation];
    projectToVouches[_project]++;
    if (projectToVouches[_project] == _settings.minVouches) _currentProjects.push(_project);
  }

  /**
   * @notice Internal function to validate the voucher's identity
   * @param _identityAttestation The attestation hash of the voucher's identity
   * @param _claimer The address of the voucher
   * @return _verified True if the voter is elegible
   */
  function _validateOptimismVoter(bytes32 _identityAttestation, address _claimer) internal returns (bool _verified) {
    if (eligibleVoter[_claimer]) revert AlreadyVerified();
    Attestation memory _attestation = EAS.getAttestation(_identityAttestation);

    if (_attestation.uid == EMPTY_UID) return false;
    if (!optimismFoundationAttester[_attestation.attester]) return false;
    if (_attestation.recipient != _claimer) return false;

    _verified = true;
    eligibleVoter[_claimer] = _verified;
    emit VoterValidated(_claimer, _identityAttestation);
  }

  /**
   * @notice Internal function to verify the project's attestation
   * @param _uid The hash of the project's Attestation
   * @return _verified True if the project is verified
   */
  function _validateProject(bytes32 _uid) internal returns (bool _verified) {
    if (eligibleProject[_uid] != address(0)) revert AlreadyVerified();
    Attestation memory _attestation = EAS.getAttestation(_uid);

    (bytes32 _projectRefId,) = abi.decode(_attestation.data, (bytes32, bytes));

    if (_attestation.recipient == address(0)) return false;
    if (!optimismFoundationAttester[_attestation.attester]) return false;
    if (_attestation.time < _settings.currentSeasonExpiry - _settings.seasonDuration) return false;
    if (!EAS.isAttestationValid(_projectRefId)) return false;

    _verified = _attestation.schema == OP_SCHEMA_638;
    if (_verified) {
      address _project = _attestation.recipient;
      eligibleProject[_uid] = _project;
      projectToExpiry[_project] = _settings.currentSeasonExpiry;
      emit ProjectValidated(_uid, _project);
    }
  }

  /**
   * @notice Remove project from the current projects list and zero out the vouches
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
    if (_value == 0) revert ZeroValue();
    if (_param == 'cycleLength') _settings.cycleLength = uint64(_value);
    else if (_param == 'currentSeasonExpiry') _settings.currentSeasonExpiry = uint64(_value);
    else if (_param == 'seasonDuration') _settings.seasonDuration = _value;
    else if (_param == 'minVouches') _settings.minVouches = _value;
    else revert InvalidParameter();
  }

  /**
   * @notice See updateOpFoundationAttester @IBuildersManager
   * @param _attester The attester address
   * @param _status The attester status
   */
  function _modifyOpFoundationAttester(address _attester, bool _status) internal {
    bool _currentStatus = optimismFoundationAttester[_attester];
    if (_currentStatus == _status) revert AlreadyUpdated(_attester);
    if (_attester == address(0)) revert ZeroValue();

    optimismFoundationAttester[_attester] = _status;

    if (_status) {
      _settings.optimismFoundationAttesters.push(_attester);
    } else {
      uint256 _l = _settings.optimismFoundationAttesters.length;
      for (uint256 _i; _i < _l; _i++) {
        if (_settings.optimismFoundationAttesters[_i] == _attester) {
          _settings.optimismFoundationAttesters[_i] = _settings.optimismFoundationAttesters[_l - 1];
          _settings.optimismFoundationAttesters.pop();
        }
      }
    }
  }
}
