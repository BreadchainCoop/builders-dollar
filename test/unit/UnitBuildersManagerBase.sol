// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BuildersDollar} from '@builders-dollar-token/BuildersDollar.sol';
import {EIP173ProxyWithReceive} from '@builders-dollar-token/vendor/EIP173ProxyWithReceive.sol';
import {Attestation, Signature} from '@eas/Common.sol';
import {IEAS} from '@eas/IEAS.sol';
import {ISchemaRegistry, SchemaRecord} from '@eas/ISchemaRegistry.sol';
import {ISchemaResolver} from '@eas/resolver/ISchemaResolver.sol';
import 'forge-std/StdJson.sol';
import {Test} from 'forge-std/Test.sol';
import {OffchainAttestation} from 'interfaces/IEasExtensions.sol';
import {Common} from 'script/Common.sol';
import 'script/Registry.sol';
import {BuilderManagerHarness} from 'test/unit/harness/BuilderManagerHarness.sol';

contract UnitBuildersManagerBase is Test, Common {
  uint256 public constant INIT_BALANCE = 1 ether;

  /// @notice BuildersManagerHarness contract for unit tests
  BuilderManagerHarness public buildersManagerHarness;

  BuildersDollar public buildersDollar;
  EIP173ProxyWithReceive public bdProxy;

  string public configPath = string(bytes('./test/unit/example_project_attestation.json'));

  address public owner = makeAddr('owner');

  OffchainAttestation public offchainAttestation;
  Attestation public identityAttestation1;
  Attestation public identityAttestation2;

  bytes32 public offchainAttestationHash;

  bytes32 public r;
  bytes32 public s;
  uint8 public v;

  bytes32 public schemaHash;

  function setUp() public virtual override {
    vm.warp(1_725_480_303);
    super.setUp();
    deployer = owner;

    vm.startPrank(owner);
    buildersManager = _deployBuildersManager();
    (buildersDollar, bdProxy) = _deployBuildersDollar();
    buildersManagerHarness = _deployBuildersManagerAsHarness();
    vm.stopPrank();

    (offchainAttestation, offchainAttestationHash) = _createOffchainAttestationsFromJson();
    identityAttestation1 = _createIdentityAttestations(ANVIL_VOTER_1);
    identityAttestation2 = _createIdentityAttestations(ANVIL_VOTER_2);

    schemaHash = _getSchemaHash();
  }

  // --- Helper Functions --- //

  function _mockVerifyIdentityAttestation(Attestation memory _identityAttestation) internal {
    vm.mockCall(
      ANVIL_EAS,
      abi.encodeWithSelector(IEAS.getAttestation.selector, _identityAttestation.uid),
      abi.encode(_identityAttestation)
    );
  }

  function _mockVerifyProjectAttestation() internal {
    SchemaRecord memory _schemaRecord =
      SchemaRecord({uid: schemaHash, resolver: ISchemaResolver(address(0x429)), revocable: false, schema: 'data'});

    vm.mockCall(
      ANVIL_EAS,
      abi.encodeWithSelector(IEAS.getSchemaRegistry.selector),
      abi.encode(ISchemaRegistry(ANVIL_EAS_SCHEMA_REGISTRY))
    );

    vm.mockCall(
      ANVIL_EAS_SCHEMA_REGISTRY,
      abi.encodeWithSelector(ISchemaRegistry.getSchema.selector, schemaHash),
      abi.encode(_schemaRecord)
    );

    vm.mockCall(
      ANVIL_EAS, abi.encodeWithSelector(IEAS.isAttestationValid.selector, offchainAttestation.refUID), abi.encode(true)
    );
  }

  function _getSchemaHash() internal view returns (bytes32 _hash) {
    string memory _configData = vm.readFile(configPath);
    _hash = bytes32(stdJson.readBytes32(_configData, '.sig.message.schema'));
  }

  function _createOffchainAttestationsFromJson()
    internal
    view
    returns (OffchainAttestation memory _attestation, bytes32 _hash)
  {
    string memory _configData = vm.readFile(configPath);

    _attestation = OffchainAttestation({
      version: uint16(stdJson.readUint(_configData, '.sig.message.version')),
      attester: ANVIL_FOUNDATION_ATTESTER_3,
      schema: bytes32(stdJson.readBytes32(_configData, '.sig.message.schema')),
      recipient: stdJson.readAddress(_configData, '.sig.message.recipient'),
      time: uint64(stdJson.readUint(_configData, '.sig.message.time')),
      expirationTime: uint64(stdJson.readUint(_configData, '.sig.message.expirationTime')),
      revocable: stdJson.readBool(_configData, '.sig.message.revocable'),
      refUID: bytes32(stdJson.readBytes32(_configData, '.sig.message.refUID')),
      data: stdJson.readBytes(_configData, '.sig.message.data'),
      signature: Signature({
        v: uint8(stdJson.readUint(_configData, '.sig.signature.v')),
        r: bytes32(stdJson.readBytes32(_configData, '.sig.signature.r')),
        s: bytes32(stdJson.readBytes32(_configData, '.sig.signature.s'))
      })
    });

    _hash = buildersManager.hashProject(_attestation);
  }

  function _createIdentityAttestations(address _recipient) internal pure returns (Attestation memory _attestation) {
    bytes memory _data; // data should be: 0x000000000000000000000000000000000000000000000000000000000003b96700000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000001350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000054775657374000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003322e310000000000000000000000000000000000000000000000000000000000

    _attestation = Attestation({
      uid: bytes32(0x2fbd12ff8d3a1724f5b915e632ef7f08ad827d2eb775faa79a2962c5c0ebf05d),
      schema: bytes32(0x41513aa7b99bfea09d389c74aacedaeb13c28fb748569e9e2400109cbe284ee5),
      time: uint64(1_725_480_303),
      expirationTime: uint64(0),
      revocationTime: uint64(0),
      refUID: bytes32(0x0),
      recipient: _recipient,
      attester: ANVIL_FOUNDATION_ATTESTER_2,
      revocable: true,
      data: _data
    });
  }
}
