// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationGreeter is IntegrationBase {
  string internal _newGreeting;

  function setUp() public override {
    /// @dev override for more specific setup
    super.setUp();
    _newGreeting = 'Hello, Breadchain!';
  }

  function test_Greet() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];

    (string memory _initialGreeting, uint256 _balance) = greeter.greet();
    assertEq(_params.greeting, _initialGreeting);
    assertEq(INIT_BALANCE, _balance);

    vm.prank(owner);
    greeter.setGreeting(_newGreeting);

    (string memory _currentGreeting,) = greeter.greet();
    assertEq(_currentGreeting, greeter.greeting());
  }
}
