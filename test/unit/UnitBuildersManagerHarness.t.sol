// SPDX-License-Identifier: PPL
pragma solidity 0.8.23;

import {UnitBuildersManagerBase} from './UnitBuildersManagerBase.sol';
import {IBuildersManager} from 'interfaces/IBuildersManager.sol';

contract VariablesForHarness {
  bytes32 public projectAttestationHash1 = keccak256('projectAttestationHash1');
  bytes32 public projectAttestationHash2 = keccak256('projectAttestationHash2');
  bytes32 public projectAttestationHash3 = keccak256('projectAttestationHash3');

  address public voter1 = address(uint160(uint256(keccak256('voter1'))));
  address public voter2 = address(uint160(uint256(keccak256('voter2'))));
  address public voter3 = address(uint160(uint256(keccak256('voter3'))));
  address public voter4 = address(uint160(uint256(keccak256('voter4'))));

  address public attacker = address(uint160(uint256(keccak256('attacker'))));
  bytes32 public invalidProjectAttestationHash = keccak256('invalidProjectAttestationHash');

  address[] public eligibleVoters = [voter1, voter2, voter3, voter4];
  bytes32[] public eligibleProjects = [projectAttestationHash1, projectAttestationHash2, projectAttestationHash3];
}

contract UnitBuildersManagerTestVouchWithHarness is UnitBuildersManagerBase, VariablesForHarness {
  function setUp() public override {
    super.setUp();
    buildersManagerHarness.populateEligibleProjects(eligibleProjects);
    buildersManagerHarness.populateEligibleVoters(eligibleVoters);
  }

  /// @notice test the initial state
  function testInitialState() public view {
    assertTrue(buildersManagerHarness.eligibleProject(projectAttestationHash1) != address(0));
    assertTrue(buildersManagerHarness.eligibleProject(projectAttestationHash2) != address(0));
    assertTrue(buildersManagerHarness.eligibleProject(projectAttestationHash3) != address(0));

    assertTrue(buildersManagerHarness.eligibleVoter(voter1));
    assertTrue(buildersManagerHarness.eligibleVoter(voter2));
    assertTrue(buildersManagerHarness.eligibleVoter(voter3));
    assertTrue(buildersManagerHarness.eligibleVoter(voter4));

    assertFalse(buildersManagerHarness.eligibleVoter(attacker));
    assertTrue(buildersManagerHarness.eligibleProject(invalidProjectAttestationHash) == address(0));

    address[] memory _currentProjects = buildersManagerHarness.currentProjects();
    assertEq(_currentProjects.length, 0);
  }

  /// @notice test adding a project after the minimum vouches
  function testAddProjectAfterMinimumVouches() public {
    vm.prank(voter1);
    buildersManagerHarness.vouch(projectAttestationHash1);

    vm.prank(voter2);
    buildersManagerHarness.vouch(projectAttestationHash1);

    address[] memory _currentProjectsAfter2Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter2Votes.length, 0);

    vm.prank(voter3);
    buildersManagerHarness.vouch(projectAttestationHash1);

    address[] memory _currentProjectsAfter3Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter3Votes.length, 1);
    assertEq(_currentProjectsAfter3Votes[0], address(buildersManagerHarness.eligibleProject(projectAttestationHash1)));

    vm.prank(voter4);
    buildersManagerHarness.vouch(projectAttestationHash1);

    address[] memory _currentProjectsAfter4Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter4Votes.length, _currentProjectsAfter3Votes.length);
  }

  /// @notice test adding a project after the minimum vouches for multiple projects
  function testAddProjectAfterMinimumVouchesForMultipleProjects() public {
    vm.startPrank(voter1);
    buildersManagerHarness.vouch(projectAttestationHash1);
    buildersManagerHarness.vouch(projectAttestationHash2);
    buildersManagerHarness.vouch(projectAttestationHash3);
    vm.stopPrank();

    vm.startPrank(voter2);
    buildersManagerHarness.vouch(projectAttestationHash1);
    buildersManagerHarness.vouch(projectAttestationHash2);
    buildersManagerHarness.vouch(projectAttestationHash3);
    vm.stopPrank();

    vm.startPrank(voter3);
    buildersManagerHarness.vouch(projectAttestationHash1);
    buildersManagerHarness.vouch(projectAttestationHash2);
    buildersManagerHarness.vouch(projectAttestationHash3);
    vm.stopPrank();

    address[] memory _currentProjectsAfter3X3Votes = buildersManagerHarness.currentProjects();
    assertEq(_currentProjectsAfter3X3Votes.length, 3);
  }

  /// @notice test distributing yield when there are no projects
  function testDistributeYieldRevertNoProjects() public {
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.YieldNoProjects.selector));
    buildersManagerHarness.distributeYield();
  }

  /// @notice test distributing yield after the cycle is ready
  function testDistributeYieldRevertAfterCycleReady() public {
    buildersManagerHarness.populateCurrentProjects(eligibleProjects);
    vm.expectRevert(abi.encodeWithSelector(IBuildersManager.CycleNotReady.selector));
    buildersManagerHarness.distributeYield();
  }
}
