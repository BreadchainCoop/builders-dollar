// SPDX-License-Identifier: PPL
pragma solidity 0.8.23;

// Tokens (Optimism Chain)
address constant OPTIMISM_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

// Contracts (Optimism Chain)
address constant OP_EAS = 0x4200000000000000000000000000000000000021;
address constant OP_BUILDERS_DOLLAR = address(0x421); // todo: fix

// Foundation Attesters (Optimism Chain)
address constant OP_FOUNDATION_ATTESTER_1 = 0xDCF7bE2ff93E1a7671724598b1526F3A33B1eC25; // gonna.eth

// Recent UIDs for Schema #638 (Optimism Chain)
bytes32 constant OP_SCHEMA_638 = 0x8aef6b9adab6252367588ad337f304da1c060cc3190f01d7b72c7e512b9bfb38;
bytes32 constant OP_SCHEMA_UID_1 = 0x9a85c61dc6b1897d4aabfe5aae7b2b726eb3c323f52bc1d52528713ad3904257;
bytes32 constant OP_SCHEMA_UID_2 = 0x165e2d5d7fb9ee4b309acb5b4f4cde497aa25ed52011a9217702570f4888cd1b;
bytes32 constant OP_SCHEMA_UID_3 = 0x7ea9127e62773fc09e2cd737721a4368c478aea9cf8e5c25d7810f41538c67dc;

// --- Mock Variables for Tests --- //

// Contracts (Anvil)
address constant ANVIL_EAS = address(0x423);
address constant ANVIL_EAS_SCHEMA_REGISTRY = 0xaAcEdAeb13C28FB748569E9e2400109cbe284eE5;
address constant ANVIL_BUILDERS_DOLLAR = address(0x425);

// Foundation Attesters (Anvil)
address constant ANVIL_FOUNDATION_ATTESTER_1 = 0x8Bc704386DCE0C4f004194684AdC44Edf6e85f07;
address constant ANVIL_FOUNDATION_ATTESTER_2 = 0xE4553b743E74dA3424Ac51f8C1E586fd43aE226F;
address constant ANVIL_FOUNDATION_ATTESTER_3 = 0xfC851dDCd27653Ff63889b4Cb494720521520958;

address constant ANVIL_VOTER_1 = 0x5C30F1273158318D3DC8FFCf991421f69fD3B77d;
address constant ANVIL_VOTER_2 = address(0x426);
