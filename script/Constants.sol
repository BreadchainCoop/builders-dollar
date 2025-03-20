// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// Tribute of 10% to Bread Coop
address constant BREAD_COOP = 0x918dEf5d593F46735f74F9E2B280Fe51AF3A99ad;

// Fixed-point multiplier
uint256 constant WAD = 1e18;

// --- Chain IDs --- //
uint256 constant OPTIMISM_CHAIN_ID = 10;
uint256 constant SEPOLIA_CHAIN_ID = 11_155_111;
uint256 constant HOLSKY_CHAIN_ID = 17_000;
uint256 constant ANVIL_CHAIN_ID = 31_337;

// --- Builders Dollar Deployment Params (Optimism Chain) --- //

// EAS Contract (Optimism Chain)
address constant OP_EAS = 0x4200000000000000000000000000000000000021;

// Foundation Attesters (Optimism Chain)
address constant OP_FOUNDATION_ATTESTER_0 = 0xDCF7bE2ff93E1a7671724598b1526F3A33B1eC25; // gonna.eth
address constant OP_FOUNDATION_ATTESTER_1 = 0xE4553b743E74dA3424Ac51f8C1E586fd43aE226F;

// Schema #638 (Optimism Chain)
bytes32 constant OP_SCHEMA_638 = 0x8aef6b9adab6252367588ad337f304da1c060cc3190f01d7b72c7e512b9bfb38;

// Recent UIDs for Schema #638 (Optimism Chain)
bytes32 constant OP_SCHEMA_UID_638_0 = 0xa5554839b21b21276b9a5c59ab950d8b56be006fdff636c0273b8bbbc3981b35; // First UID for Schema #638 that includes a recipient address (Optimism Chain)
bytes32 constant OP_SCHEMA_UID_638_1 = 0x9a85c61dc6b1897d4aabfe5aae7b2b726eb3c323f52bc1d52528713ad3904257;
bytes32 constant OP_SCHEMA_UID_638_2 = 0x165e2d5d7fb9ee4b309acb5b4f4cde497aa25ed52011a9217702570f4888cd1b;
bytes32 constant OP_SCHEMA_UID_638_3 = 0x7ea9127e62773fc09e2cd737721a4368c478aea9cf8e5c25d7810f41538c67dc;

// Schema #599 (Optimism Chain)
bytes32 constant OP_SCHEMA_599 = 0x41513aa7b99bfea09d389c74aacedaeb13c28fb748569e9e2400109cbe284ee5;

// Recent UIDs for Schema #599 (Optimism Chain)
bytes32 constant OP_SCHEMA_UID_599_0 = 0x47bce32815e138de601f34e5f4d17116fe0f22d866cc5acc271c7aabc7dcf9e9;
bytes32 constant OP_SCHEMA_UID_599_1 = 0xabd013b11bf0ed3d9856633a89c2ea80da776ca06626cd89b66e5ce204a9928d;
bytes32 constant OP_SCHEMA_UID_599_2 = 0xff88ab7ad81e0582bd9e5d34298f837cebcec9b8d0f03e282e899e8329027ba4;
bytes32 constant OP_SCHEMA_UID_599_3 = 0xec6e0ca3a831031555948ddaaed5de73af707b150586ca70a5fb163e425b0227;

// --- UBS-USD Token Deployment Params (Optimism Chain) --- //

address constant OP_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // USDC
address constant OP_A_USDC = 0x625E7708f30cA75bfd92586e17077590C60eb4cD; // aUSDC

address constant OP_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
address constant OP_A_DAI = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;

address constant OP_AAVE_V3_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
address constant OP_AAVE_V3_INCENTIVES = 0x929EC64c34a17401F460460D4B9390518E5B473e;

string constant OBSUSD_NAME = 'Builders Dollar';
string constant OBSUSD_SYMBOL = 'OBSUSD';

// --- Aave V2 (Optimism Chain) --- //
address constant OP_WETH_GATEWAY = 0x86b4D2636EC473AC4A5dD83Fc2BEDa98845249A7;

// ------------------------------- /
// Warning:
// Mock Variables for Anvil Tests Below
// ------------------------------- //

// Contracts (Anvil)
address constant ANVIL_EAS = address(0x423);
address constant ANVIL_EAS_SCHEMA_REGISTRY = 0xaAcEdAeb13C28FB748569E9e2400109cbe284eE5;
address constant ANVIL_BUILDERS_DOLLAR = address(0x425);

// Foundation Attesters (Anvil)
address constant ANVIL_FOUNDATION_ATTESTER_0 = 0x8Bc704386DCE0C4f004194684AdC44Edf6e85f07;
address constant ANVIL_FOUNDATION_ATTESTER_1 = 0xE4553b743E74dA3424Ac51f8C1E586fd43aE226F;
address constant ANVIL_FOUNDATION_ATTESTER_2 = 0xfC851dDCd27653Ff63889b4Cb494720521520958;

address constant ANVIL_VOTER_0 = 0x5C30F1273158318D3DC8FFCf991421f69fD3B77d;
address constant ANVIL_VOTER_1 = address(0x426);
