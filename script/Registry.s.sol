// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// --- ARB Sepolia Testnet ---

// Governance Settings
uint256 constant TEST_INIT_VOTING_DELAY = 1;
uint256 constant TEST_INIT_VOTING_PERIOD = 15;
uint256 constant TEST_INIT_PROP_THRESHOLD = 0;

// Deployment params
uint256 constant MIN_DELAY_GOERLI = 1 minutes;
uint256 constant ORACLE_INTERVAL_TEST = 1 minutes;

// Members for governance
address constant H = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
address constant J = 0xcb81A76a565aC4870EDA5B0e32c5a0D2ec734174;
address constant P = 0xC295763Eed507d4A0f8B77241c03dd3354781a15;

// Vanity address params - use `cast create2` to find salt (salt must change for each deployment)
uint256 constant SEPOLIA_SALT_SYSTEMCOIN = 3;
uint256 constant SEPOLIA_SALT_PROTOCOLTOKEN = 3;
uint256 constant SEPOLIA_SALT_VAULT721 = 3;
address constant SEPOLIA_CREATE2_FACTORY = 0xb9d4cbCcF0152040c3269D9701EE68426196e42a;

// Camelot Relayer (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_CAMELOT_RELAYER_FACTORY = address(0);
address constant SEPOLIA_CAMELOT_RELAYER = address(0);

// Algebra protocol
address constant SEPOLIA_ALGEBRA_FACTORY = 0x21852176141b8D139EC5D3A1041cdC31F0F20b94;

// Chainlink feeds
address constant SEPOLIA_CHAINLINK_ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
address constant SEPOLIA_CHAINLINK_ARB_USD_FEED = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;

// Unverified WETH token
address constant SEPOLIA_WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

// --- ARB Mainnet ---

// Governance Settings
uint256 constant MAINNET_INIT_VOTING_DELAY = 332_308;
uint256 constant MAINNET_INIT_VOTING_PERIOD = 2_326_156;
uint256 constant MAINNET_INIT_PROP_THRESHOLD = 0;

// Deployment params
address constant DAO_SAFE = address(1); // set this before mainnet deployment
uint256 constant AIRDROP_AMOUNT = 10_000e18; // 10k tokens
uint256 constant MIN_DELAY = 3 days; // timelock for governor
uint256 constant ORACLE_INTERVAL_PROD = 1 hours;

// Vanity address params - use `cast create2` to find salt
uint256 constant MAINNET_SALT_SYSTEMCOIN = 0;
uint256 constant MAINNET_SALT_PROTOCOLTOKEN = 0;
uint256 constant MAINNET_SALT_VAULT721 = 0;
address constant MAINNET_CREATE2_FACTORY = address(0);

// Camelot Relayer (pre-deployed @ sol 0.7.6)
address constant MAINNET_CAMELOT_RELAYER_FACTORY = address(0);
address constant MAINNET_CAMELOT_RELAYER = address(0);

// Camelot Protocol
address constant CAMELOT_AMM_FACTORY = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

// Token contracts (all 18 decimals)
address constant ARBITRUM_WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
address constant ARBITRUM_ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
address constant ARBITRUM_CBETH = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f;
address constant ARBITRUM_RETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
address constant ARBITRUM_MAGIC = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;

// Chainlink feeds to USD
address constant CHAINLINK_ARB_USD_FEED = 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6;
address constant CHAINLINK_ETH_USD_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

// Chainlink feeds to ETH
address constant CHAINLINK_WSTETH_ETH_FEED = 0xb523AE262D20A936BC152e6023996e46FDC2A95D;
address constant CHAINLINK_CBETH_ETH_FEED = 0xa668682974E3f121185a3cD94f00322beC674275;
address constant CHAINLINK_RETH_ETH_FEED = 0xF3272CAfe65b190e76caAF483db13424a3e23dD2;

// --- Anvil Local Testnet ---

// Members for governance
address constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
address constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
address constant CHARLOTTE = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
