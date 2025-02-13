// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Attestation, EMPTY_UID} from '@eas/Common.sol';
import {TransparentUpgradeableProxy} from '@oz/proxy/transparent/TransparentUpgradeableProxy.sol';
import {BuildersManager, IBuildersManager} from 'contracts/BuildersManager.sol';
import {Test} from 'forge-std/Test.sol';

contract BaseTest is Test {
  IBuildersManager public buildersManager;
  address public token = makeAddr('builders-dollar');
  address public eas = makeAddr('eas');

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

    // Mock initial settings
    mockSettings(_settings);
  }

  // --- Helper Functions ---

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
      vm.mockCall(
        address(token),
        abi.encodeWithSignature('transfer(address,uint256)', recipients[i], amountPerRecipient),
        abi.encode(true)
      );
    }
  }

  function _makeVoterEligible(address voter, bytes32 identityAttestation) internal {
    Attestation memory mockIdentityAttestation =
      _createMockAttestation(identityAttestation, bytes32(0), voter, address(this), '');
    _mockEASAttestation(identityAttestation, mockIdentityAttestation);

    vm.prank(voter);
    buildersManager.validateOptimismVoter(identityAttestation);
  }

  function _setupProjectAttestation(
    address project,
    bytes32 attestation,
    bytes32 projectRefId
  ) internal returns (bytes memory) {
    bytes memory attestationData = abi.encode(projectRefId, '');

    Attestation memory mockAttestation =
      _createMockAttestation(attestation, buildersManager.OP_SCHEMA_638(), project, address(this), attestationData);

    _mockEASAttestation(attestation, mockAttestation);
    vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', projectRefId), abi.encode(true));

    return attestationData;
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

  function mockVouchWithIdentity(bytes32 projectAttestation, bytes32 identityAttestation) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSignature('vouch(bytes32,bytes32)', projectAttestation, identityAttestation),
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

  function expectValidateOptimismVoter(bytes32 attestation) public {
    vm.expectCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.validateOptimismVoter.selector, attestation)
    );
  }

  function expectVouch(bytes32 projectAttestation) public {
    vm.expectCall(address(buildersManager), abi.encodeWithSignature('vouch(bytes32)', projectAttestation));
  }

  function expectVouchWithIdentity(bytes32 projectAttestation, bytes32 identityAttestation) public {
    vm.expectCall(
      address(buildersManager),
      abi.encodeWithSignature('vouch(bytes32,bytes32)', projectAttestation, identityAttestation)
    );
  }

  function expectDistributeYield() public {
    vm.expectCall(address(buildersManager), abi.encodeWithSelector(IBuildersManager.distributeYield.selector));
  }

  function expectModifyParams(bytes32 param, uint256 value) public {
    vm.expectCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.modifyParams.selector, param, value)
    );
  }

  function expectUpdateOpFoundationAttester(address attester, bool status) public {
    vm.expectCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.updateOpFoundationAttester.selector, attester, status)
    );
  }

  function expectBatchUpdateOpFoundationAttesters(address[] memory attesters, bool[] memory statuses) public {
    vm.expectCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.batchUpdateOpFoundationAttesters.selector, attesters, statuses)
    );
  }

  // --- View Function Mock Helpers ---

  function mockSettings(IBuildersManager.BuilderManagerSettings memory settings) public {
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.settings.selector), abi.encode(settings)
    );
  }

  function mockCurrentProjects(address[] memory projects) public {
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.currentProjects.selector), abi.encode(projects)
    );
  }

  function mockOptimismFoundationAttesters(address[] memory attesters) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.optimismFoundationAttesters.selector),
      abi.encode(attesters)
    );
  }

  function mockEligibleVoter(address voter, bool isEligible) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.eligibleVoter.selector, voter),
      abi.encode(isEligible)
    );
  }

  function mockEligibleProject(bytes32 uid, address project) public {
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.eligibleProject.selector, uid),
      abi.encode(project)
    );
  }

  function mockVouchedProjects(uint256 numProjects, uint256 vouchesPerProject) public returns (address[] memory) {
    // Create array of project addresses
    address[] memory projects = new address[](numProjects);
    for (uint256 i = 0; i < numProjects; i++) {
      projects[i] = address(uint160(i + 1)); // Use i+1 to avoid address(0)
    }

    // For each project, create attestation and mock vouches
    for (uint256 i = 0; i < numProjects; i++) {
      // Create and mock project attestation
      bytes32 projectUid = keccak256(abi.encodePacked('project', i));
      bytes32 projectRefId = keccak256(abi.encodePacked('projectRef', i));
      bytes memory attestationData = abi.encode(projectRefId, '');

      Attestation memory projectAttestation =
        _createMockAttestation(projectUid, buildersManager.OP_SCHEMA_638(), projects[i], address(this), attestationData);
      _mockEASAttestation(projectUid, projectAttestation);

      // Mock project reference attestation as valid
      vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', projectRefId), abi.encode(true));

      // Mock project as eligible
      mockEligibleProject(projectUid, projects[i]);

      // Create vouchers and mock their attestations
      for (uint256 j = 0; j < vouchesPerProject; j++) {
        address voter = address(uint160(100 + (i * vouchesPerProject) + j)); // Unique voter addresses starting at 100
        bytes32 voterUid = keccak256(abi.encodePacked('voter', i, j));

        // Create and mock voter's identity attestation
        bytes32 voterRefId = keccak256(abi.encodePacked('voterRef', i, j));
        bytes memory voterData = abi.encode(voterRefId, '');
        Attestation memory voterAttestation =
          _createMockAttestation(voterUid, buildersManager.OP_SCHEMA_638(), voter, address(this), voterData);
        _mockEASAttestation(voterUid, voterAttestation);

        // Mock voter reference attestation as valid
        vm.mockCall(address(eas), abi.encodeWithSignature('isAttestationValid(bytes32)', voterRefId), abi.encode(true));

        // Mock voter as eligible
        mockEligibleVoter(voter, true);

        // Mock the vouch call to succeed
        vm.prank(voter);
        buildersManager.vouch(projectUid, voterUid);
      }
    }

    // Mock the projects array as current projects
    mockCurrentProjects(projects);

    return projects;
  }
}
