// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable2StepUpgradeable} from '@oz-upgradeable/access/Ownable2StepUpgradeable.sol';
import {Ownable} from '@oz/access/Ownable.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationDeploy is IntegrationBase {
  function test_OBSUSD_Bytecode() public view {
    assertGt(address(obUsdToken).code.length, 0);
  }

  function test_BuildersManager_Bytecode() public view {
    assertGt(address(builderManager).code.length, 0);
  }

  function test_Ownable() public view {
    assertEq(Ownable(address(obUsdToken)).owner(), initialOwner);
    assertEq(Ownable(address(builderManager)).owner(), initialOwner);
    assertEq(Ownable2StepUpgradeable(address(builderManager)).pendingOwner(), address(0));
  }
}
