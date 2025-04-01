// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from '@oz/access/Ownable.sol';
import {IBuilderManager} from 'contracts/BuilderManager.sol';
import {BaseTest} from 'test/unit/BaseTest.sol';

contract UnitAttesterTest is BaseTest {
  function test_UpdateOpFoundationAttesterWhenCalledWithValidAddress() public {
    address newAttester = address(0x123);

    // Check initial state
    address[] memory initialAttesters = builderManager.optimismFoundationAttesters();
    bool initiallyIncluded = false;
    for (uint256 i = 0; i < initialAttesters.length; i++) {
      if (initialAttesters[i] == newAttester) {
        initiallyIncluded = true;
        break;
      }
    }
    assertFalse(initiallyIncluded, 'Attester should not be included initially');

    // Update attester
    builderManager.updateOpFoundationAttester(newAttester, true);

    // Check final state
    address[] memory finalAttesters = builderManager.optimismFoundationAttesters();
    bool finallyIncluded = false;
    for (uint256 i = 0; i < finalAttesters.length; i++) {
      if (finalAttesters[i] == newAttester) {
        finallyIncluded = true;
        break;
      }
    }
    assertTrue(finallyIncluded, 'Attester should be included after update');

    // Test AlreadyUpdated error
    vm.expectRevert(abi.encodeWithSelector(IBuilderManager.AlreadyUpdated.selector, newAttester));
    builderManager.updateOpFoundationAttester(newAttester, true);

    // Remove attester
    builderManager.updateOpFoundationAttester(newAttester, false);

    // Check state after removal
    address[] memory afterRemovalAttesters = builderManager.optimismFoundationAttesters();
    bool includedAfterRemoval = false;
    for (uint256 i = 0; i < afterRemovalAttesters.length; i++) {
      if (afterRemovalAttesters[i] == newAttester) {
        includedAfterRemoval = true;
        break;
      }
    }
    assertFalse(includedAfterRemoval, 'Attester should not be included after removal');
  }

  function test_UpdateOpFoundationAttesterWhenCalledWithZeroAddress() public {
    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.updateOpFoundationAttester(address(0), true);
  }

  function test_UpdateOpFoundationAttesterWhenCalledByNonOwner() public {
    address nonOwner = address(0x456);
    address newAttester = address(0x123);

    vm.prank(nonOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
    builderManager.updateOpFoundationAttester(newAttester, true);
  }

  function test_BatchUpdateOpFoundationAttestersWhenCalledWithValidAddresses() public {
    address[] memory attesters = new address[](3);
    attesters[0] = address(0x1);
    attesters[1] = address(0x2);
    attesters[2] = address(0x3);

    bool[] memory statuses = new bool[](3);
    statuses[0] = true;
    statuses[1] = true;
    statuses[2] = true;

    // Check initial state
    address[] memory initialAttesters = builderManager.optimismFoundationAttesters();
    for (uint256 i = 0; i < attesters.length; i++) {
      bool initiallyIncluded = false;
      for (uint256 j = 0; j < initialAttesters.length; j++) {
        if (initialAttesters[j] == attesters[i]) {
          initiallyIncluded = true;
          break;
        }
      }
      if (statuses[i]) {
        assertFalse(initiallyIncluded, 'Attester should not be included initially');
      }
    }

    // Batch update attesters
    builderManager.batchUpdateOpFoundationAttesters(attesters, statuses);

    // Check final state
    address[] memory finalAttesters = builderManager.optimismFoundationAttesters();
    for (uint256 i = 0; i < attesters.length; i++) {
      bool finallyIncluded = false;
      for (uint256 j = 0; j < finalAttesters.length; j++) {
        if (finalAttesters[j] == attesters[i]) {
          finallyIncluded = true;
          break;
        }
      }
      if (statuses[i]) {
        assertTrue(finallyIncluded, 'Attester should be included after update');
      } else {
        assertFalse(finallyIncluded, 'Attester should not be included after update');
      }
    }
  }

  function test_BatchUpdateOpFoundationAttestersWhenCalledWithMismatchedArrays() public {
    address[] memory attesters = new address[](2);
    attesters[0] = address(0x1);
    attesters[1] = address(0x2);

    bool[] memory statuses = new bool[](3);
    statuses[0] = true;
    statuses[1] = false;
    statuses[2] = true;

    vm.expectRevert(IBuilderManager.InvalidLength.selector);
    builderManager.batchUpdateOpFoundationAttesters(attesters, statuses);
  }

  function test_BatchUpdateOpFoundationAttestersWhenCalledWithZeroAddress() public {
    address[] memory attesters = new address[](3);
    attesters[0] = address(0x1);
    attesters[1] = address(0); // Zero address
    attesters[2] = address(0x3);

    bool[] memory statuses = new bool[](3);
    statuses[0] = true;
    statuses[1] = true;
    statuses[2] = true;

    vm.expectRevert(IBuilderManager.ZeroValue.selector);
    builderManager.batchUpdateOpFoundationAttesters(attesters, statuses);
  }

  function test_BatchUpdateOpFoundationAttestersWhenCalledByNonOwner() public {
    address nonOwner = address(0x456);
    address[] memory attesters = new address[](1);
    attesters[0] = address(0x1);
    bool[] memory statuses = new bool[](1);
    statuses[0] = true;

    vm.prank(nonOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
    builderManager.batchUpdateOpFoundationAttesters(attesters, statuses);
  }
}
