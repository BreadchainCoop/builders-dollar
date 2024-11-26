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

contract BuildersManager is EIP712Upgradeable, Ownable2StepUpgradeable, IBuildersManager {
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
  BuilderManagerParams internal _params;

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
   * @notice Modifier to check if the user has already vouched for the project
   * @param _projectAttestation The attestation hash of the project
   */
  modifier eligible(bytes32 _projectAttestation) {
    if (eligibleProject[_projectAttestation] == address(0)) revert InvalidProjectAttestation();
    if (voterToProjectVouch[msg.sender][_projectAttestation]) revert AlreadyVouched();
    _;
  }

  // --- Initializer ---

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  // TODO: add param enforcement modifiers
  /// @inheritdoc IBuildersManager
  function initialize(
    address _token,
    address _eas,
    string memory _name,
    string memory _version,
    BuilderManagerParams memory __params
  ) external initializer {
    __EIP712_init(_name, _version);

    TOKEN = BuildersDollar(_token);
    EAS = IEAS(_eas);
    _params = __params;

    uint256 _l = _params.optimismFoundationAttesters.length;
    for (uint256 _i; _i < _l; ++_i) {
      optimismFoundationAttester[_params.optimismFoundationAttesters[_i]] = true;
    }
  }

  // --- External Methods ---

  // TODO: does this need access control?
  /// @inheritdoc IBuildersManager
  function attestProject(OffchainAttestation calldata _attestation) external {
    if (!_validateProject(_attestation)) revert InvalidProjectAttestation();
  }

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectAttestation) external eligible(_projectAttestation) {
    if (!eligibleVoter[msg.sender]) revert IdAttestationRequired();
    voterToProjectVouch[msg.sender][_projectAttestation] = true;
  }

  /// @inheritdoc IBuildersManager
  function vouch(bytes32 _projectAttestation, bytes32 _identityAttestation) external eligible(_projectAttestation) {
    if (!eligibleVoter[msg.sender]) {
      if (!_validateOptimismVoter(_identityAttestation, msg.sender)) revert InvalidIdAttestation();
    }
    voterToProjectVouch[msg.sender][_projectAttestation] = true;
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

  // --- Internal Utilities ---

  /**
   * @notice Function to validate the voucher's identity
   * @param _identityAttestation The attestation hash of the voucher's identity
   * @param _claimer The address of the voucher
   * @return _verified True if the voter is elegible
   */
  function _validateOptimismVoter(bytes32 _identityAttestation, address _claimer) internal returns (bool _verified) {
    Attestation memory _attestation = EAS.getAttestation(_identityAttestation);

    if (_attestation.uid == bytes32(0)) {
      _verified = false;
    } else if (!optimismFoundationAttester[_attestation.attester]) {
      _verified = false;
    } else if (_attestation.recipient != _claimer) {
      _verified = false;
    } else {
      (uint256 farcasterID,,,,) = abi.decode(_attestation.data, (uint256, string, string, string, string));

      _verified = true;
      eligibleVoter[_claimer] = _verified;
      emit VoterValidated(_claimer, farcasterID);
    }
  }

  /**
   * @notice Function to verify the project's attestation
   * @param _attestation The project's Attestation
   * @return _verified True if the project is verified
   */
  function _validateProject(OffchainAttestation calldata _attestation) internal returns (bool _verified) {
    SchemaRecord memory schemaRecord = EAS.getSchemaRegistry().getSchema(_attestation.schema);

    if (schemaRecord.uid == EMPTY_UID) {
      _verified = false;
    } else if (!optimismFoundationAttester[_attestation.attester]) {
      _verified = false;
    } else if (_attestation.version != _VERSION1) {
      _verified = false;
    } else if (_attestation.time < _params.currentSeasonExpiry - _params.seasonDuration) {
      _verified = false;
    } else if (_attestation.expirationTime < block.timestamp) {
      _verified = false;
    } else if (_attestation.refUID != EMPTY_UID) {
      _verified = false;
    } else if (!EAS.isAttestationValid(_attestation.refUID)) {
      _verified = false;
    } else {
      bytes32 _projectHash = _hashTypedDataV4(
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
      Signature memory _sig = _attestation.signature;

      _verified = SignatureChecker.isValidSignatureNow(
        _attestation.attester, _projectHash, abi.encodePacked(_sig.r, _sig.s, _sig.v)
      );
      if (_verified) {
        address _project = _attestation.recipient;
        _currentProjects.push(_project);
        eligibleProject[_projectHash] = _project;
        projectToExpiry[_project] = _params.currentSeasonExpiry;

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
