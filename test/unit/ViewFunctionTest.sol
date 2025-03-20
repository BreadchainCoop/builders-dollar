// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBuildersManager} from 'contracts/BuildersManager.sol';
import {BaseTest} from 'test/unit/BaseTest.sol';

contract UnitViewFunctionTest is BaseTest {
  function test_GetSettingsWhenCalled() public {
    IBuildersManager.BuilderManagerSettings memory expectedSettings = IBuildersManager.BuilderManagerSettings({
      cycleLength: 7 days,
      lastClaimedTimestamp: uint64(block.timestamp),
      fundingExpiry: uint64(304 days),
      seasonStart: uint64(1_704_067_200),
      seasonDuration: 90 days,
      minVouches: 3,
      optimismFoundationAttesters: new address[](1)
    });
    expectedSettings.optimismFoundationAttesters[0] = address(this);

    mockSettings(expectedSettings);

    IBuildersManager.BuilderManagerSettings memory actualSettings = buildersManager.settings();
    assertEq(actualSettings.cycleLength, expectedSettings.cycleLength);
    assertEq(actualSettings.lastClaimedTimestamp, expectedSettings.lastClaimedTimestamp);
    assertEq(actualSettings.fundingExpiry, expectedSettings.fundingExpiry);
    assertEq(actualSettings.seasonStart, expectedSettings.seasonStart);
    assertEq(actualSettings.seasonDuration, expectedSettings.seasonDuration);
    assertEq(actualSettings.minVouches, expectedSettings.minVouches);
    assertEq(actualSettings.optimismFoundationAttesters[0], expectedSettings.optimismFoundationAttesters[0]);
  }

  function test_GetCurrentProjectsWhenCalled() public {
    address[] memory expectedProjects = new address[](3);
    expectedProjects[0] = address(0x1);
    expectedProjects[1] = address(0x2);
    expectedProjects[2] = address(0x3);

    mockCurrentProjects(expectedProjects);

    address[] memory actualProjects = buildersManager.currentProjects();
    assertEq(actualProjects.length, expectedProjects.length);
    for (uint256 i = 0; i < actualProjects.length; i++) {
      assertEq(actualProjects[i], expectedProjects[i]);
    }
  }

  function test_GetOptimismFoundationAttestersWhenCalled() public {
    address[] memory expectedAttesters = new address[](2);
    expectedAttesters[0] = address(0x1);
    expectedAttesters[1] = address(0x2);

    mockOptimismFoundationAttesters(expectedAttesters);

    address[] memory actualAttesters = buildersManager.optimismFoundationAttesters();
    assertEq(actualAttesters.length, expectedAttesters.length);
    for (uint256 i = 0; i < actualAttesters.length; i++) {
      assertEq(actualAttesters[i], expectedAttesters[i]);
    }
  }

  function test_IsEligibleVoterWhenCalled() public {
    address voter = address(0x123);

    // Test when voter is eligible
    mockEligibleVoter(voter, true);
    assertTrue(buildersManager.eligibleVoter(voter));

    // Test when voter is not eligible
    mockEligibleVoter(voter, false);
    assertFalse(buildersManager.eligibleVoter(voter));
  }

  function test_GetEligibleProjectWhenCalled() public {
    bytes32 projectAttestation = bytes32(uint256(1));
    address expectedProject = address(0x123);

    mockEligibleProject(projectAttestation, expectedProject);

    address actualProject = buildersManager.eligibleProject(projectAttestation);
    assertEq(actualProject, expectedProject);
  }

  function test_GetEligibleProjectByUidWhenCalled() public {
    address project = address(0x123);
    bytes32 expectedUid = bytes32(uint256(1));

    // Mock the call
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.eligibleProjectByUid.selector, project),
      abi.encode(expectedUid)
    );

    bytes32 actualUid = buildersManager.eligibleProjectByUid(project);
    assertEq(actualUid, expectedUid);
  }

  function test_GetProjectToVouchersWhenCalled() public {
    address project = address(0x123);
    address[] memory expectedVouchers = new address[](3);
    expectedVouchers[0] = address(0x1);
    expectedVouchers[1] = address(0x2);
    expectedVouchers[2] = address(0x3);

    // Mock the call
    vm.mockCall(
      address(buildersManager),
      abi.encodeWithSelector(IBuildersManager.projectToVouchers.selector, project),
      abi.encode(expectedVouchers)
    );

    address[] memory actualVouchers = buildersManager.projectToVouchers(project);
    assertEq(actualVouchers.length, expectedVouchers.length);
    for (uint256 i = 0; i < actualVouchers.length; i++) {
      assertEq(actualVouchers[i], expectedVouchers[i]);
    }
  }
}
