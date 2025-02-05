// SPDX-License-Identifier: PPL
pragma solidity 0.8.27;

import {Attestation} from '@eas/Common.sol';
import {IEAS} from '@eas/IEAS.sol';
import {SchemaRecord} from '@eas/ISchemaRegistry.sol';
import {Test} from 'forge-std/Test.sol';
import {Common} from 'script/Common.sol';
import {IBuildersManager} from 'src/interfaces/IBuildersManager.sol';
// solhint-disable-next-line
import 'script/Registry.sol';

contract IntegrationBase is Common, Test {
  uint256 public constant INIT_BALANCE = 1 ether;

  address public user = makeAddr('user');
  address public owner = makeAddr('owner');

  function setUp() public virtual override {
    super.setUp();
    deployer = owner;
    vm.createSelectFork(vm.rpcUrl('optimism'));

    vm.startPrank(owner);
    buildersManager = IBuildersManager(address(_deployBuildersManager()));
    vm.stopPrank();
  }
}

contract IntegrationEAS is IntegrationBase {
  IEAS internal _eas;

  bytes32 internal _uid1 = OP_SCHEMA_UID_1;
  bytes32 internal _uid2 = OP_SCHEMA_UID_2;
  bytes32 internal _uid3 = OP_SCHEMA_UID_3;

  Attestation internal _attestation1;
  Attestation internal _attestation2;
  Attestation internal _attestation3;

  function setUp() public override {
    super.setUp();
    _eas = buildersManager.EAS();
    _attestation1 = _eas.getAttestation(_uid1);
    _attestation2 = _eas.getAttestation(_uid2);
    _attestation3 = _eas.getAttestation(_uid3);
  }

  function testGetAttestationSchema() public view {
    SchemaRecord memory _schemaRecord = _eas.getSchemaRegistry().getSchema(_attestation1.schema);

    assertEq(_schemaRecord.uid, OP_SCHEMA_638);
    assertEq(_attestation1.schema, OP_SCHEMA_638);
    assertEq(_attestation2.schema, OP_SCHEMA_638);
    assertEq(_attestation3.schema, OP_SCHEMA_638);
  }
}
