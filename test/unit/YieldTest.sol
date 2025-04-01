// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBuilderManager} from 'contracts/BuilderManager.sol';
import {BaseTest} from 'test/unit/BaseTest.sol';

contract UnitYieldTest is BaseTest {
  uint256 public constant CURRENT_TIME = 1000 days;
  uint64 public constant CYCLE_LENGTH = 30 days;
  uint64 public constant SEASON_DURATION = 365 days;
  uint256 public constant MIN_VOUCHES = 3;
  uint256 public constant PROJECT_COUNT = 3;

  function test_DistributeYieldWhenNoProjects() public {
    vm.warp(CURRENT_TIME);

    // Setup with cycle ready
    _setupSettings(uint64(CURRENT_TIME - CYCLE_LENGTH), uint64(CURRENT_TIME));

    // Mock empty projects array
    address[] memory emptyProjects = new address[](0);
    mockCurrentProjects(emptyProjects);

    vm.expectRevert(IBuilderManager.YieldNoProjects.selector);
    builderManager.distributeYield();
  }

  function test_DistributeYieldWhenSeasonExpired() public {
    vm.warp(CURRENT_TIME);

    // Setup with cycle ready but expired season
    _setupSettings(uint64(CURRENT_TIME - CYCLE_LENGTH), uint64(CURRENT_TIME - SEASON_DURATION - 1 days));

    // Setup projects with expired timestamps
    address[] memory projects = _setupProjects(PROJECT_COUNT, CURRENT_TIME - 1 days);

    // Setup token operations
    _setupTokenOperations(projects, 1000 ether);

    vm.expectRevert(IBuilderManager.YieldNoProjects.selector);
    builderManager.distributeYield();
  }

  // --- Internal Helpers ---

  function _setupSettings(uint64 _lastClaimedTimestamp, uint64 _seasonStart) internal {
    IBuilderManager.BuilderManagerSettings memory _settings = IBuilderManager.BuilderManagerSettings({
      cycleLength: CYCLE_LENGTH,
      lastClaimedTimestamp: _lastClaimedTimestamp,
      fundingExpiry: uint64(304 days),
      seasonStart: _seasonStart,
      seasonDuration: SEASON_DURATION,
      minVouches: MIN_VOUCHES,
      optimismFoundationAttesters: new address[](1)
    });
    _settings.optimismFoundationAttesters[0] = address(this);
    mockSettings(_settings);

    // Set lastClaimedTimestamp directly in storage
    bytes32 _settingsSlot = bytes32(uint256(4));
    bytes32 _currentValue = vm.load(address(builderManager), _settingsSlot);
    bytes32 _clearedValue = bytes32(uint256(_currentValue) & 0xFFFFFFFFFFFFFFFF);
    bytes32 _newValue = bytes32(uint256(_clearedValue) | (uint256(_lastClaimedTimestamp) << 64));
    vm.store(address(builderManager), _settingsSlot, _newValue);
  }

  /**
   * @notice storage layout of BuilderManager
   * Storage slots in BuilderManager:
   * slot 0: TOKEN (address)
   * slot 1: EAS (address)
   * slot 2: voterSchema (bytes32)
   * slot 3: projectSchema (bytes32)
   * slots 4-7: _settings (struct)
   *   slot 4: cycleLength, lastClaimedTimestamp, fundingExpiry
   *   slot 5: seasonStart, seasonDuration
   *   slot 6: minVouches
   *   slot 7: optimismFoundationAttesters array pointer
   * slot 8: schemaToValidator (mapping)
   * slot 9: optimismFoundationAttester (mapping)
   * slot 10: eligibleVoter (mapping)
   * slot 11: eligibleProject (mapping)
   * slot 12: eligibleProjectByUid (mapping)
   * slot 13: projectToExpiry (mapping)
   * slot 14: projectToVouches (mapping)
   * slot 15: voterToProjectVouch (mapping)
   * slot 16: _projectToVouchers (mapping)
   * slot 17: _currentProjects (array)
   */
  function _setupProjects(uint256 _count, uint256 _expiryTime) internal returns (address[] memory _projects) {
    _projects = new address[](_count);
    for (uint256 i = 0; i < _count; i++) {
      _projects[i] = makeAddr(string.concat('project', vm.toString(i)));
    }

    // Setup array storage for _currentProjects
    bytes32 _slot = bytes32(uint256(17));
    vm.store(address(builderManager), _slot, bytes32(_count));
    bytes32 _arrayStartSlot = keccak256(abi.encodePacked(_slot));

    for (uint256 i = 0; i < _count; i++) {
      // Store project address in _currentProjects array
      bytes32 _itemSlot = bytes32(uint256(_arrayStartSlot) + i);
      bytes32 _itemValue = bytes32(uint256(uint160(_projects[i])));
      vm.store(address(builderManager), _itemSlot, _itemValue);

      // Create a UID for each project
      bytes32 _projectUid = bytes32(uint256(i + 1)); // Use simple incremental UIDs

      // Set up the eligibleProject mapping (slot 11) directly in storage
      bytes32 _eligibleProjectSlot = keccak256(abi.encode(_projectUid, uint256(11)));
      vm.store(address(builderManager), _eligibleProjectSlot, bytes32(uint256(uint160(_projects[i]))));

      // Set up the eligibleProjectByUid mapping (slot 12) directly in storage
      bytes32 _eligibleProjectByUidSlot = keccak256(abi.encode(_projects[i], uint256(12)));
      vm.store(address(builderManager), _eligibleProjectByUidSlot, _projectUid);

      // Store project expiry in projectToExpiry mapping (slot 13)
      bytes32 _expirySlot = keccak256(abi.encode(_projects[i], uint256(13)));
      vm.store(address(builderManager), _expirySlot, bytes32(uint256(_expiryTime)));

      // Store project vouches count in projectToVouches mapping (slot 14)
      bytes32 _vouchesSlot = keccak256(abi.encode(_projects[i], uint256(14)));
      vm.store(address(builderManager), _vouchesSlot, bytes32(uint256(MIN_VOUCHES)));

      // Also mock the function calls that read these values
      vm.mockCall(
        address(builderManager),
        abi.encodeWithSelector(IBuilderManager.eligibleProject.selector, _projectUid),
        abi.encode(_projects[i])
      );

      vm.mockCall(
        address(builderManager),
        abi.encodeWithSelector(IBuilderManager.eligibleProjectByUid.selector, _projects[i]),
        abi.encode(_projectUid)
      );

      vm.mockCall(
        address(builderManager),
        abi.encodeWithSelector(IBuilderManager.projectToVouches.selector, _projects[i]),
        abi.encode(MIN_VOUCHES)
      );
    }

    // Also mock the currentProjects call to ensure consistency
    vm.mockCall(
      address(builderManager), abi.encodeWithSelector(IBuilderManager.currentProjects.selector), abi.encode(_projects)
    );

    return _projects;
  }

  function _setupTokenOperations(
    address[] memory _projects,
    uint256 _yieldAmount
  ) internal returns (uint256 _yieldPerProject) {
    _yieldPerProject = _yieldAmount / _projects.length;
    _mockTokenOperations(_yieldAmount, _projects);
    vm.mockCall(
      address(builderManager), abi.encodeWithSelector(IBuilderManager.currentProjects.selector), abi.encode(_projects)
    );
  }
}
