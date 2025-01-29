// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {BaseTest} from './BaseTest.sol';
import {IBuildersManager} from 'contracts/BuildersManager.sol';

contract UnitYieldTest is BaseTest {
  // function test_DistributeYieldWhenCycleIsReady() public {
  //   // Warp to a specific timestamp first
  //   vm.warp(1000 days);
  //   uint256 currentTime = block.timestamp;

  //   // Setup mock projects with required vouches
  //   address[] memory projects = new address[](3);
  //   for (uint256 i = 0; i < 3; i++) {
  //     projects[i] = makeAddr(string.concat('project', vm.toString(i)));
  //   }

  //   // Mock the internal _currentProjects array state
  //   vm.store(
  //     address(buildersManager),
  //     bytes32(uint256(5)), // slot for _currentProjects array length
  //     bytes32(uint256(3)) // length of 3
  //   );

  //   for (uint256 i = 0; i < projects.length; i++) {
  //     vm.store(
  //       address(buildersManager),
  //       keccak256(abi.encode(5)), // slot for _currentProjects array data
  //       bytes32(uint256(uint160(projects[i])))
  //     );
  //   }

  //   // Mock settings with cycle ready
  //   IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
  //     cycleLength: 7 days,
  //     lastClaimedTimestamp: uint64(currentTime - 8 days), // Last claim was more than a cycle ago
  //     currentSeasonExpiry: uint64(currentTime + 90 days),
  //     seasonDuration: 90 days,
  //     minVouches: 3,
  //     optimismFoundationAttesters: new address[](1)
  //   });
  //   settings.optimismFoundationAttesters[0] = address(this);
  //   mockSettings(settings);

  //   // Mock project expiry times to be in the future
  //   for (uint256 i = 0; i < projects.length; i++) {
  //     vm.mockCall(
  //       address(buildersManager),
  //       abi.encodeWithSelector(IBuildersManager.projectToExpiry.selector, projects[i]),
  //       abi.encode(currentTime + 90 days)
  //     );
  //   }

  //   // Mock token operations
  //   uint256 yieldAmount = 1000 ether;
  //   uint256 yieldPerProject = yieldAmount / projects.length;
  //   _mockTokenOperations(yieldAmount, projects);

  //   // Mock the currentProjects view function
  //   vm.mockCall(
  //     address(buildersManager), abi.encodeWithSelector(IBuildersManager.currentProjects.selector), abi.encode(projects)
  //   );

  //   // Expect events
  //   vm.expectEmit(true, true, true, true);
  //   emit IBuildersManager.YieldDistributed(yieldPerProject, projects);

  //   // Distribute yield
  //   buildersManager.distributeYield();
  // }

  // function test_DistributeYieldWhenCycleIsNotReady() public {
  //   // Setup mock projects with required vouches
  //   address[] memory projects = mockVouchedProjects(2, 3); // 2 projects, each with 3 vouches

  //   // Mock settings with cycle not ready
  //   IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
  //     cycleLength: 7 days,
  //     lastClaimedTimestamp: uint64(block.timestamp), // Set to current time to ensure cycle is not ready
  //     currentSeasonExpiry: uint64(block.timestamp + 90 days),
  //     seasonDuration: 90 days,
  //     minVouches: 3,
  //     optimismFoundationAttesters: new address[](1)
  //   });
  //   settings.optimismFoundationAttesters[0] = address(this);
  //   mockSettings(settings);

  //   // Expect revert
  //   vm.expectRevert(IBuildersManager.CycleNotReady.selector);
  //   buildersManager.distributeYield();
  // }

  function test_DistributeYieldWhenNoProjects() public {
    // Mock settings with cycle ready
    IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 7 days,
      lastClaimedTimestamp: uint64(block.timestamp - 7 days),
      currentSeasonExpiry: uint64(block.timestamp + 90 days),
      seasonDuration: 90 days,
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    settings.optimismFoundationAttesters[0] = address(this);
    mockSettings(settings);

    // Mock empty projects array
    address[] memory emptyProjects = new address[](0);
    mockCurrentProjects(emptyProjects);

    // Expect revert
    vm.expectRevert(IBuildersManager.YieldNoProjects.selector);
    buildersManager.distributeYield();
  }

  // function test_DistributeYieldWhenSeasonExpired() public {
  //   // Mock settings with expired season first
  //   uint64 seasonExpiry = uint64(block.timestamp - 1); // Past expiry
  //   IBuildersManager.BuilderManagerSettings memory settings = IBuildersManager.BuilderManagerSettings({
  //     cycleLength: 7 days,
  //     lastClaimedTimestamp: uint64(block.timestamp - 7 days),
  //     currentSeasonExpiry: seasonExpiry,
  //     seasonDuration: 90 days,
  //     minVouches: 3,
  //     optimismFoundationAttesters: new address[](1)
  //   });
  //   settings.optimismFoundationAttesters[0] = address(this);
  //   mockSettings(settings);

  //   // Setup mock projects with required vouches
  //   address[] memory projects = mockVouchedProjects(2, 3); // 2 projects, each with 3 vouches

  //   // Mock project expiry times to be in the past (which will trigger ejection with new logic)
  //   for (uint256 i = 0; i < projects.length; i++) {
  //     vm.mockCall(
  //       address(buildersManager),
  //       abi.encodeWithSelector(IBuildersManager.projectToExpiry.selector, projects[i]),
  //       abi.encode(block.timestamp - 1) // Past expiry will trigger ejection
  //     );
  //   }

  //   // Mock token operations
  //   uint256 yieldAmount = 1000 ether;
  //   _mockTokenOperations(yieldAmount, projects);

  //   // Warp time forward to ensure we're past the cycle length
  //   vm.warp(block.timestamp + 8 days); // More than cycleLength (7 days)

  //   // Expect revert with YieldNoProjects since all projects will be ejected
  //   vm.expectRevert(IBuildersManager.YieldNoProjects.selector);
  //   buildersManager.distributeYield();
  // }
}
