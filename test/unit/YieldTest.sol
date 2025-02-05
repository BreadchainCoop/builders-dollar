// SPDX-License-Identifier: UNLICENSED
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

  function _setupSettings(uint64 lastClaimedTimestamp, uint64 currentSeasonExpiry) internal {
    IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: CYCLE_LENGTH,
      lastClaimedTimestamp: lastClaimedTimestamp,
      currentSeasonExpiry: currentSeasonExpiry,
      seasonDuration: SEASON_DURATION,
      minVouches: MIN_VOUCHES,
      optimismFoundationAttesters: new address[](1)
    });
    settings.optimismFoundationAttesters[0] = address(this);
    mockSettings(settings);

    // Set lastClaimedTimestamp directly in storage
    bytes32 settingsSlot = bytes32(uint256(2));
    bytes32 currentValue = vm.load(address(buildersManager), settingsSlot);
    bytes32 clearedValue = bytes32(uint256(currentValue) & 0xFFFFFFFFFFFFFFFF);
    bytes32 newValue = bytes32(uint256(clearedValue) | (uint256(lastClaimedTimestamp) << 64));
    vm.store(address(buildersManager), settingsSlot, newValue);
  }

  function _setupProjects(uint256 count, uint256 expiryTime) internal returns (address[] memory projects) {
    projects = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      projects[i] = makeAddr(string.concat('project', vm.toString(i)));
    }

    // Setup array storage
    bytes32 slot = bytes32(uint256(12));
    vm.store(address(buildersManager), slot, bytes32(count));
    bytes32 arrayStartSlot = keccak256(abi.encodePacked(slot));

    for (uint256 i = 0; i < count; i++) {
      // Store project address
      bytes32 itemSlot = bytes32(uint256(arrayStartSlot) + i);
      bytes32 itemValue = bytes32(uint256(uint160(projects[i])));
      vm.store(address(buildersManager), itemSlot, itemValue);

      // Store project expiry
      bytes32 expirySlot = keccak256(abi.encode(projects[i], uint256(9)));
      vm.store(address(buildersManager), expirySlot, bytes32(uint256(expiryTime)));

      // Setup attestations and vouches
      bytes32 projectUid = keccak256(abi.encodePacked('project', i));
      mockEligibleProject(projectUid, projects[i]);
      vm.mockCall(
        address(buildersManager),
        abi.encodeWithSelector(IBuildersManager.projectToVouches.selector, projects[i]),
        abi.encode(MIN_VOUCHES)
      );
    }
  }

  function _setupTokenOperations(
    address[] memory projects,
    uint256 yieldAmount
  ) internal returns (uint256 yieldPerProject) {
    yieldPerProject = yieldAmount / projects.length;
    _mockTokenOperations(yieldAmount, projects);
    vm.mockCall(
      address(buildersManager), abi.encodeWithSelector(IBuildersManager.currentProjects.selector), abi.encode(projects)
    );
  }
}
