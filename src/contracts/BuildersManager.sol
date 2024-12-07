// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {Attestation, EMPTY_UID, Signature} from '@eas/Common.sol';
import {IEAS} from '@eas/IEAS.sol';
import {SchemaRecord} from '@eas/ISchemaRegistry.sol';
import {Ownable2StepUpgradeable} from '@oz-upgradeable/access/Ownable2StepUpgradeable.sol';
import {EIP712Upgradeable} from '@oz-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import {SignatureChecker} from '@oz/utils/cryptography/SignatureChecker.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';
import {OffchainAttestation} from 'interfaces/IEasExtensions.sol';

import {Test} from 'forge-std/Test.sol';

// TODO: Remove Test
contract BuildersManager is EIP712Upgradeable, Ownable2StepUpgradeable, IBuildersManager, Test {
  /// @notice The mutliplier used for fixed-point division
  uint256 private constant _PRECISION = 1e18;
  /// @notice The version of the offchain attestation
  uint16 private constant _VERSION1 = 1;
  /// @notice Hash of the data type used to relay calls to the attest function
  bytes32 private constant _VERSION1_ATTEST_TYPEHASH = keccak256(
    'Attest(uint16 version,bytes32 schema,address recipient,uint64 time,uint64 expirationTime,bool revocable,bytes32 refUID,bytes data)'
  );

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
  mapping(bytes32 _projectAttestation => address _project) public eligibleProject;
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
  function vouch(OffchainAttestation calldata _offchainProjectAttestation) external {
    if (!_validateProject(_offchainProjectAttestation)) revert InvalidProjectAttestation();
    _vouch(hashProject(_offchainProjectAttestation), msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function vouch(OffchainAttestation calldata _offchainProjectAttestation, bytes32 _identityAttestation) external {
    if (!_validateOptimismVoter(_identityAttestation, msg.sender)) revert InvalidIdAttestation();
    if (!_validateProject(_offchainProjectAttestation)) revert InvalidProjectAttestation();
    _vouch(hashProject(_offchainProjectAttestation), msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectAttestation) external {
    _vouch(_projectAttestation, msg.sender);
  }

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectAttestation, bytes32 _identityAttestation) external {
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

    for (uint256 _i; _i < _l; ++_i) {
      address _project = _currentProjects[_i];
      if (projectToExpiry[_project] > block.timestamp) _ejectProject(_project);
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

  // --- Public Methods ---

  /// @inheritdoc IBuildersManager
  function hashProject(OffchainAttestation calldata _attestation) public view returns (bytes32 _projectHash) {
    _projectHash = _hashTypedDataV4(
      keccak256(
        abi.encode(
          _VERSION1_ATTEST_TYPEHASH,
          _VERSION1,
          _attestation.schema,
          _attestation.recipient,
          _attestation.time,
          _attestation.expirationTime,
          _attestation.revocable,
          _attestation.refUID,
          keccak256(_attestation.data)
        )
      )
    );
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

    if (_attestation.uid == bytes32(0)) {
      _verified = false;
    } else if (!optimismFoundationAttester[_attestation.attester]) {
      _verified = false;
    } else if (_attestation.recipient != _claimer) {
      _verified = false;
    } else {
      _verified = true;
      eligibleVoter[_claimer] = _verified;
      emit VoterValidated(_claimer, _identityAttestation);
    }
  }

  /**
   * @notice Internal function to verify the project's attestation
   * @param _attestation The project's Attestation
   * @return _verified True if the project is verified
   */
  function _validateProject(OffchainAttestation calldata _attestation) internal returns (bool _verified) {
    bytes32 _projectHash = hashProject(_attestation);
    if (eligibleProject[_projectHash] != address(0)) revert AlreadyVerified();

    SchemaRecord memory _schemaRecord = EAS.getSchemaRegistry().getSchema(_attestation.schema);

    if (_schemaRecord.uid == EMPTY_UID) {
      _verified = false;
    } else if (!optimismFoundationAttester[_attestation.attester]) {
      _verified = false;
    } else if (_attestation.version != _VERSION1) {
      _verified = false;
    } else if (_attestation.time < _settings.currentSeasonExpiry - _settings.seasonDuration) {
      _verified = false;
    } else if (_attestation.expirationTime != 0 && _attestation.expirationTime < block.timestamp) {
      _verified = false;
    } else if (_attestation.refUID != EMPTY_UID) {
      _verified = false;
    } else if (!EAS.isAttestationValid(_attestation.refUID)) {
      _verified = false;
    } else {
      Signature memory _sig = _attestation.signature;

      _verified = SignatureChecker.isValidSignatureNow(
        _attestation.attester, _projectHash, abi.encodePacked(_sig.r, _sig.s, _sig.v)
      );
      if (_verified) {
        address _project = _attestation.recipient;
        eligibleProject[_projectHash] = _project;
        projectToExpiry[_project] = _settings.currentSeasonExpiry;

        emit ProjectValidated(_projectHash, _project);
      }
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
    if (_param == 'cycleLength') _settings.cycleLength = uint64(_value);
    else if (_param == 'lastClaimedTimestamp') _settings.lastClaimedTimestamp = uint64(_value);
    else if (_param == 'currentSeasonExpiry') _settings.currentSeasonExpiry = uint64(_value);
    else if (_param == 'seasonDuration') _settings.seasonDuration = _value;
    else if (_param == 'minVouches') _settings.minVouches = _value;
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
