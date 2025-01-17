// SPDX-License-Identifier: PPL
pragma solidity 0.8.23;

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

contract E2EEAS is IntegrationBase {
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

  function testDecodeData1() public {
    (
      bytes32 _projectRefId,
      string memory _incentOp,
      string memory _buildersOp,
      string memory _season,
      string memory _intent,
      string memory _mission,
      string memory _approvalDate,
      string memory _metadataUrl
    ) = abi.decode(_attestation1.data, (bytes32, string, string, string, string, string, string, string));
    assertTrue(_projectRefId != bytes32(0));
    emit log_named_bytes32('_projectRefId', _projectRefId);
    emit log_named_string('_incentOp', _incentOp);
    emit log_named_string('_buildersOp', _buildersOp);
    emit log_named_string('_season', _season);
    emit log_named_string('_intent', _intent);
    emit log_named_string('_mission', _mission);
    emit log_named_string('_approvalDate', _approvalDate);
    emit log_named_string('_metadataUrl', _metadataUrl);
  }

  function testDecodeData2() public {
    (
      bytes32 _projectRefId,
      string memory _incentOp,
      string memory _buildersOp,
      ,
      ,
      ,
      string memory _approvalDate,
      string memory _metadataUrl
    ) = abi.decode(_attestation2.data, (bytes32, string, string, string, string, string, string, string));
    assertTrue(_projectRefId != bytes32(0));
    emit log_named_bytes32('_projectRefId', _projectRefId);
    emit log_named_string('_incentOp', _incentOp);
    emit log_named_string('_buildersOp', _buildersOp);
    emit log_named_string('_approvalDate', _approvalDate);
    emit log_named_string('_metadataUrl', _metadataUrl);
  }

  function testDecodeData3() public {
    (bytes32 _projectRefId,) = abi.decode(_attestation3.data, (bytes32, bytes));
    assertTrue(_projectRefId != bytes32(0));
  }

  function testGetRecipient() public {
    // assertEq(_attestation1.recipient, ANVIL_VOTER_1);
    // assertEq(_attestation2.recipient, ANVIL_VOTER_2);
    emit log_named_address('attestation1.recipient', _attestation1.recipient);
    emit log_named_address('attestation2.recipient', _attestation2.recipient);
    emit log_named_address('attestation3.recipient', _attestation3.recipient);
  }

  function testGetAttesters() public {
    emit log_named_address('attestation1.attester', _attestation1.attester);
    emit log_named_address('attestation2.attester', _attestation2.attester);
    emit log_named_address('attestation3.attester', _attestation3.attester);
  }
}
