// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationBuildersManager is IntegrationBase {
  function test_NullTest() public pure {
    assertTrue(true);
  }
}
