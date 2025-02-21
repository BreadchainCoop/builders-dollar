// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BaseTest} from './BaseTest.sol';
import {IBuildersManager} from 'contracts/BuildersManager.sol';

contract UnitYieldTest is BaseTest {
  uint256 public constant CURRENT_TIME = 1000 days;
  uint64 public constant CYCLE_LENGTH = 7 days;
  uint64 public constant SEASON_DURATION = 90 days;
  uint256 public constant MIN_VOUCHES = 3;
  uint256 public constant PROJECT_COUNT = 3;

  function test_DistributeYieldWhenCycleIsReady() public {
    vm.warp(CURRENT_TIME);

    // Setup with cycle ready (last claim was 8 days ago)
    _setupSettings(uint64(CURRENT_TIME - 8 days), uint64(CURRENT_TIME + SEASON_DURATION));

    // Setup projects with future expiry
    address[] memory projects = _setupProjects(PROJECT_COUNT, CURRENT_TIME + 365 days);

    // Setup token operations and expect event
    uint256 yieldPerProject = _setupTokenOperations(projects, 1000 ether);
    vm.expectEmit(true, true, true, true);
    emit IBuildersManager.YieldDistributed(yieldPerProject, projects);

    buildersManager.distributeYield();
  }

  function test_RevertWhenCycleNotReady() public {
    vm.warp(CURRENT_TIME);

    // Setup with cycle not ready (last claim was 1 day ago)
    _setupSettings(uint64(CURRENT_TIME - 1 days), uint64(CURRENT_TIME + SEASON_DURATION));

    // Setup projects with future expiry
    address[] memory projects = _setupProjects(PROJECT_COUNT, CURRENT_TIME + 365 days);

    // Setup token operations
    _setupTokenOperations(projects, 1000 ether);

    vm.expectRevert(IBuildersManager.CycleNotReady.selector);
    buildersManager.distributeYield();
  }

  function test_DistributeYieldWhenNoProjects() public {
    vm.warp(CURRENT_TIME);

    // Setup with cycle ready
    _setupSettings(uint64(CURRENT_TIME - CYCLE_LENGTH), uint64(CURRENT_TIME + SEASON_DURATION));

    // Mock empty projects array
    address[] memory emptyProjects = new address[](0);
    mockCurrentProjects(emptyProjects);

    vm.expectRevert(IBuildersManager.YieldNoProjects.selector);
    buildersManager.distributeYield();
  }

  function test_DistributeYieldWhenSeasonExpired() public {
    vm.warp(CURRENT_TIME);

    // Setup with cycle ready but expired season
    _setupSettings(uint64(CURRENT_TIME - CYCLE_LENGTH), uint64(CURRENT_TIME - 1 days));

    // Setup projects with expired timestamps
    address[] memory projects = _setupProjects(PROJECT_COUNT, CURRENT_TIME - 1 days);

    // Setup token operations
    _setupTokenOperations(projects, 1000 ether);

    vm.expectRevert(IBuildersManager.YieldNoProjects.selector);
    buildersManager.distributeYield();
  }

  // --- Internal Helpers ---

  function _setupSettings(uint64 _lastClaimedTimestamp, uint64 _currentSeasonExpiry) internal {
    IBuildersManager.BuilderManagerSettings memory _settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: CYCLE_LENGTH,
      lastClaimedTimestamp: _lastClaimedTimestamp,
      currentSeasonExpiry: _currentSeasonExpiry,
      seasonDuration: SEASON_DURATION,
      minVouches: MIN_VOUCHES,
      optimismFoundationAttesters: new address[](1)
    });
    _settings.optimismFoundationAttesters[0] = address(this);
    mockSettings(_settings);

    // Set lastClaimedTimestamp directly in storage
    bytes32 _settingsSlot = bytes32(uint256(2));
    bytes32 _currentValue = vm.load(address(buildersManager), _settingsSlot);
    bytes32 _clearedValue = bytes32(uint256(_currentValue) & 0xFFFFFFFFFFFFFFFF);
    bytes32 _newValue = bytes32(uint256(_clearedValue) | (uint256(_lastClaimedTimestamp) << 64));
    vm.store(address(buildersManager), _settingsSlot, _newValue);
  }

  /**
   * @notice storage layout of BuildersManager
   * Storage slots in BuildersManager:
   * slot 0: TOKEN (address)
   * slot 1: EAS (address)
   * slots 2-5: _settings (struct)
   *   slot 2: cycleLength, lastClaimedTimestamp, currentSeasonExpiry
   *   slot 3: seasonDuration
   *   slot 4: minVouches
   *   slot 5: optimismFoundationAttesters array pointer
   * slot 6: optimismFoundationAttester (mapping)
   * slot 7: eligibleVoter (mapping)
   * slot 8: eligibleProject (mapping)
   * slot 9: eligibleProjectByUid (mapping)
   * slot 10: projectToExpiry (mapping)
   * slot 11: projectToVouches (mapping)
   * slot 12: voterToProjectVouch (mapping)
   * slot 13: _projectToVouchers (mapping)
   * slot 14: _currentProjects (array)
   */
  function _setupProjects(uint256 _count, uint256 _expiryTime) internal returns (address[] memory _projects) {
    _projects = new address[](_count);
    for (uint256 i = 0; i < _count; i++) {
      _projects[i] = makeAddr(string.concat('project', vm.toString(i)));
    }

    // Setup array storage for _currentProjects
    bytes32 _slot = bytes32(uint256(14));
    vm.store(address(buildersManager), _slot, bytes32(_count));
    bytes32 _arrayStartSlot = keccak256(abi.encodePacked(_slot));

    for (uint256 i = 0; i < _count; i++) {
      // Store project address in _currentProjects array
      bytes32 _itemSlot = bytes32(uint256(_arrayStartSlot) + i);
      bytes32 _itemValue = bytes32(uint256(uint160(_projects[i])));
      vm.store(address(buildersManager), _itemSlot, _itemValue);

      // Store project expiry in projectToExpiry mapping (slot 10)
      bytes32 _expirySlot = keccak256(abi.encode(_projects[i], uint256(10)));
      vm.store(address(buildersManager), _expirySlot, bytes32(uint256(_expiryTime)));

      // Setup attestations and vouches
      bytes32 _projectUid = bytes32(uint256(i + 1)); // Use simple incremental UIDs
      mockEligibleProject(_projectUid, _projects[i]);

      // Mock the project to UID mapping
      vm.mockCall(
        address(buildersManager),
        abi.encodeWithSelector(IBuildersManager.eligibleProjectByUid.selector, _projects[i]),
        abi.encode(_projectUid)
      );

      // Mock the vouches count
      vm.mockCall(
        address(buildersManager),
        abi.encodeWithSelector(IBuildersManager.projectToVouches.selector, _projects[i]),
        abi.encode(MIN_VOUCHES)
      );
    }
  }

  function _setupTokenOperations(
    address[] memory _projects,
    uint256 _yieldAmount
  ) internal returns (uint256 _yieldPerProject) {
    _yieldPerProject = _yieldAmount / _projects.length;
    _mockTokenOperations(_yieldAmount, _projects);
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.currentProjects.selector), abi.encode(_projects)
    );
  }
}
