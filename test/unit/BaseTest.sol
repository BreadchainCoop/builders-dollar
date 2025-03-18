// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {SchemaRecord} from '@eas/ISchemaRegistry.sol';
import {ISchemaResolver} from '@eas/resolver/ISchemaResolver.sol';
import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';
import {SchemaValidator599} from 'contracts/schemas/SchemaValidator599.sol';
import {SchemaValidator638} from 'contracts/schemas/SchemaValidator638.sol';
import {Test} from 'forge-std/Test.sol';
import {OP_SCHEMA_599, OP_SCHEMA_638} from 'script/Constants.sol';

contract BaseTest is Test {
  IBuildersManager public buildersManager;
  address public token = makeAddr('builders-dollar');
  address public eas = makeAddr('eas');
  address public voterSchemaValidator;
  address public projectSchemaValidator;

  // Test variables
  bytes32 public identityAttestation = bytes32(uint256(2));

  function setUp() public virtual {
    // Warp to a more realistic mainnet state
    vm.warp(1_704_067_200); // January 1, 2024 UTC
    vm.roll(19_000_000); // A recent Ethereum block number

    // Deploy implementation
    BuildersManager implementation = new BuildersManager();

    // Initialize with required parameters
    IBuildersManager.BuilderManagerSettings memory _settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 7 days,
      lastClaimedTimestamp: uint64(block.timestamp),
      currentSeasonExpiry: uint64(block.timestamp + 90 days),
      seasonDuration: 90 days,
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    _settings.optimismFoundationAttesters[0] = address(this);

    // Deploy proxy and initialize
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(implementation),
      address(this),
      abi.encodeWithSelector(IBuildersManager.initialize.selector, token, eas, 'BuildersManager', '1', _settings)
    );

    buildersManager = IBuildersManager(address(proxy));

    // Mock EAS schema registry before creating schema validators
    mockEASSchemaRegistry();

    voterSchemaValidator = address(new SchemaValidator599(OP_SCHEMA_599, address(buildersManager)));
    projectSchemaValidator = address(new SchemaValidator638(OP_SCHEMA_638, address(buildersManager)));
    buildersManager.registerSchema(OP_SCHEMA_599, voterSchemaValidator);
    buildersManager.registerSchema(OP_SCHEMA_638, projectSchemaValidator);
    buildersManager.setSchemaValidator('voterSchema', OP_SCHEMA_599);
    buildersManager.setSchemaValidator('projectSchema', OP_SCHEMA_638);

    // Mock initial settings
    mockSettings(_settings);
  }

  // --- Helper Functions ---

  /**
   * @notice Mocks the EAS.getSchemaRegistry() call to return a mock schema registry address
   * @dev This is needed for schema validators to initialize properly in tests
   */
  function mockEASSchemaRegistry() public returns (address) {
    address mockSchemaRegistry = makeAddr('schema-registry');
    vm.label(mockSchemaRegistry, 'schema-registry');

    // Mock the getSchemaRegistry call
    vm.mockCall(eas, abi.encodeWithSignature('getSchemaRegistry()'), abi.encode(mockSchemaRegistry));

    // Mock getSchema for OP_SCHEMA_599 (voter schema)
    // Create a SchemaRecord with the correct UID
    vm.mockCall(
      mockSchemaRegistry,
      abi.encodeWithSignature('getSchema(bytes32)', OP_SCHEMA_599),
      abi.encode(
        SchemaRecord({uid: OP_SCHEMA_599, resolver: ISchemaResolver(address(0)), revocable: true, schema: 'VoterSchema'})
      )
    );

    // Mock getSchema for OP_SCHEMA_638 (project schema)
    vm.mockCall(
      mockSchemaRegistry,
      abi.encodeWithSignature('getSchema(bytes32)', OP_SCHEMA_638),
      abi.encode(
        SchemaRecord({
          uid: OP_SCHEMA_638,
          resolver: ISchemaResolver(address(0)),
          revocable: true,
          schema: 'ProjectSchema'
        })
      )
    );

    return mockSchemaRegistry;
  }

  function _createMockAttestation(
    bytes32 uid,
    bytes32 schema,
    address recipient,
    address attester,
    bytes memory data
  ) internal view returns (Attestation memory) {
    return Attestation({
      uid: uid,
      schema: schema,
      time: uint64(block.timestamp),
      expirationTime: uint64(block.timestamp + 365 days),
      revocationTime: uint64(0),
      refUID: EMPTY_UID,
      recipient: recipient,
      attester: attester,
      revocable: true,
      data: data
    });
  }

  function _mockEASAttestation(bytes32 uid, Attestation memory attestation) internal {
    vm.mockCall(address(eas), abi.encodeWithSignature('getAttestation(bytes32)', uid), abi.encode(attestation));
  }

  function _mockTokenOperations(uint256 yieldAmount, address[] memory recipients) internal {
    // Mock yield accrual
    vm.mockCall(address(token), abi.encodeWithSignature('yieldAccrued()'), abi.encode(yieldAmount));

    // Mock claim yield
    vm.mockCall(address(token), abi.encodeWithSignature('claimYield(uint256)', yieldAmount), abi.encode());

    // Mock transfers
    uint256 amountPerRecipient = yieldAmount / recipients.length;
    for (uint256 i = 0; i < recipients.length; i++) {
      // Mock BuildersDollar.TOKEN() call
      vm.mockCall(address(token), abi.encodeWithSignature('TOKEN()'), abi.encode(token));
      vm.mockCall(
        address(token),
        abi.encodeWithSignature('transfer(address,uint256)', recipients[i], amountPerRecipient),
        abi.encode(true)
      );
    }
  }

  function _setupProjectAttestation(
    address project,
    bytes32 attestation,
    bytes32 projectRefId
  ) internal returns (bytes memory) {
    bytes memory attestationData = abi.encode(projectRefId, '');

    Attestation memory mockAttestation =
      _createMockAttestation(attestation, OP_SCHEMA_638, project, address(this), attestationData);

    _mockEASAttestation(attestation, mockAttestation);
    vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', projectRefId), abi.encode(true));

    return attestationData;
  }

  function _setupVoterAttestation() internal {
    // Create voter attestation data with the correct schema and format
    // Format: (uint256 refId, string name, string voterType, string level, string version)
    bytes memory voterData = abi.encode(uint256(320_694), 'Voter', 'Guest', 'C', '3.2');

    // Create mock identity attestation with correct schema
    Attestation memory mockIdentityAttestation =
      _createMockAttestation(identityAttestation, OP_SCHEMA_599, address(this), address(this), voterData);

    // Mock the EAS call for getting the attestation
    _mockEASAttestation(identityAttestation, mockIdentityAttestation);
  }

  // --- Mock Helpers ---

  function mockValidateOptimismVoter(bytes32 attestation, bool result) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.validateOptimismVoter.selector, attestation),
      abi.encode(result)
    );
  }

  function mockVouch(bytes32 projectAttestation) public {
    vm.mockCall(address(buildersManager), abi.encodeWithSignature('vouch(bytes32)', projectAttestation), abi.encode());
  }

  function mockVouchWithIdentity(bytes32 projectAttestation, bytes32 _identityAttestation) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSignature('vouch(bytes32,bytes32)', projectAttestation, _identityAttestation),
      abi.encode()
    );
  }

  function mockDistributeYield() public {
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.distributeYield.selector), abi.encode()
    );
  }

  function mockModifyParams(bytes32 param, uint256 value) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.modifyParams.selector, param, value),
      abi.encode()
    );
  }

  function mockUpdateOpFoundationAttester(address attester, bool status) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.updateOpFoundationAttester.selector, attester, status),
      abi.encode()
    );
  }

  function mockBatchUpdateOpFoundationAttesters(address[] memory attesters, bool[] memory statuses) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.batchUpdateOpFoundationAttesters.selector, attesters, statuses),
      abi.encode()
    );
  }

  // --- Expect Helpers ---

  function expectValidateOptimismVoter(bytes32 _attestation) public {
    vm.expectCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.validateOptimismVoter.selector, _attestation)
    );
  }

  function expectVouch(bytes32 _projectAttestation) public {
    vm.expectCall(address(buildersManager), abi.encodeWithSignature('vouch(bytes32)', _projectAttestation));
  }

  function expectVouchWithIdentity(bytes32 _projectAttestation, bytes32 _identityAttestation) public {
    vm.expectCall(
      address(buildersManager),
      abi.encodeWithSignature('vouch(bytes32,bytes32)', _projectAttestation, _identityAttestation)
    );
  }

  function expectDistributeYield() public {
    vm.expectCall(address(buildersManager), abi.encodeWithSelector(IBuildersManager.distributeYield.selector));
  }

  function expectModifyParams(bytes32 _param, uint256 _value) public {
    vm.expectCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.modifyParams.selector, _param, _value)
    );
  }

  function expectUpdateOpFoundationAttester(address _attester, bool _status) public {
    vm.expectCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.updateOpFoundationAttester.selector, _attester, _status)
    );
  }

  function expectBatchUpdateOpFoundationAttesters(address[] memory _attesters, bool[] memory _statuses) public {
    vm.expectCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.batchUpdateOpFoundationAttesters.selector, _attesters, _statuses)
    );
  }

  // --- View Function Mock Helpers ---

  function mockSettings(IBuildersManager.BuilderManagerSettings memory _settings) public {
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.settings.selector), abi.encode(_settings)
    );
  }

  function mockCurrentProjects(address[] memory _projects) public {
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.currentProjects.selector), abi.encode(_projects)
    );
  }

  function mockOptimismFoundationAttesters(address[] memory _attesters) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.optimismFoundationAttesters.selector),
      abi.encode(_attesters)
    );
  }

  function mockEligibleVoter(address _voter, bool _isEligible) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.eligibleVoter.selector, _voter),
      abi.encode(_isEligible)
    );
  }

  function mockEligibleProject(bytes32 _uid, address _project) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.eligibleProject.selector, _uid),
      abi.encode(_project)
    );
  }

  function mockVouchedProjects(uint256 _numProjects, uint256 _vouchesPerProject) public returns (address[] memory) {
    // Create array of project addresses
    address[] memory _projects = new address[](_numProjects);
    for (uint256 i = 0; i < _numProjects; i++) {
      _projects[i] = address(uint160(i + 1)); // Use i+1 to avoid address(0)
    }

    // For each project, create attestation and mock vouches
    for (uint256 i = 0; i < _numProjects; i++) {
      // Create and mock project attestation
      bytes32 _projectUid = keccak256(abi.encodePacked('project', i));
      bytes32 _projectRefId = keccak256(abi.encodePacked('projectRef', i));
      bytes memory _attestationData = abi.encode(_projectRefId, '');

      Attestation memory _projectAttestation =
        _createMockAttestation(_projectUid, OP_SCHEMA_638, _projects[i], address(this), _attestationData);
      _mockEASAttestation(_projectUid, _projectAttestation);

      // Mock project reference attestation as valid
      vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', _projectRefId), abi.encode(true));

      // Mock project as eligible
      mockEligibleProject(_projectUid, _projects[i]);

      // Create vouchers and mock their attestations
      for (uint256 j = 0; j < _vouchesPerProject; j++) {
        address _voter = address(uint160(100 + (i * _vouchesPerProject) + j)); // Unique voter addresses starting at 100
        bytes32 _voterUid = keccak256(abi.encodePacked('voter', i, j));

        // Create and mock voter's identity attestation
        bytes32 _voterRefId = keccak256(abi.encodePacked('voterRef', i, j));
        bytes memory _voterData = abi.encode(_voterRefId, '');
        Attestation memory _voterAttestation =
          _createMockAttestation(_voterUid, OP_SCHEMA_638, _voter, address(this), _voterData);
        _mockEASAttestation(_voterUid, _voterAttestation);

        // Mock voter reference attestation as valid
        vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', _voterRefId), abi.encode(true));

        // Mock voter as eligible
        mockEligibleVoter(_voter, true);

        // Mock the vouch call to succeed
        vm.prank(_voter);
        buildersManager.vouch(_projectUid, _voterUid);
      }
    }

    // Mock the projects array as current projects
    mockCurrentProjects(_projects);
    return _projects;
  }
}
