// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuildersManager} from 'contracts/BuildersManager.sol';

contract BuilderManagerHarness is BuildersManager {
  function populateEligibleProjects(bytes32[] memory _projectAttestations) public {
    for (uint256 i = 0; i < _projectAttestations.length; i++) {
      eligibleProject[_projectAttestations[i]] = address(uint160(0x420 + i));
    }
  }

  function populateEligibleVoters(address[] memory _voters) public {
    for (uint256 i = 0; i < _voters.length; i++) {
      eligibleVoter[_voters[i]] = true;
    }
  }

  function populateCurrentProjects(bytes32[] memory _projectAttestations) public {
    for (uint256 i = 0; i < _projectAttestations.length; i++) {
      address _project = address(uint160(0x420 + i));
      eligibleProject[_projectAttestations[i]] = _project;
      _currentProjects.push(_project);
    }
  }
}
