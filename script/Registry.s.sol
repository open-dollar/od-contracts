// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// --- Universal Vars ---
uint256 constant SEMI_RANDOM_SALT = 0; // set to 0 to use Salts below, set to 1 to randomly generate a salt

// --- ARB Sepolia Testnet ---

// Create2 Factory
address constant TEST_CREATE2FACTORY = 0xd7729CC26096035e1A7e834cE0b72599Da25FA7f;

// Protocol Token
address constant SEPOLIA_PROTOCOL_TOKEN = 0xFEEe338C2A70FC4F754C68c788973a7634b83d5b;

// Governance Settings
uint256 constant TEST_INIT_VOTING_DELAY = 1;
uint256 constant TEST_INIT_VOTING_PERIOD = 15;
uint256 constant TEST_INIT_PROP_THRESHOLD = 0;

// Deployment params
address constant TEST_DEPLOYER = 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1;
address constant TEST_SAFE = 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1;
uint256 constant MIN_DELAY_GOERLI = 1 minutes;
uint256 constant ORACLE_INTERVAL_TEST = 1 minutes;

// Members for governance
address constant H = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
address constant J = 0xcb81A76a565aC4870EDA5B0e32c5a0D2ec734174;
address constant P = 0xC295763Eed507d4A0f8B77241c03dd3354781a15;

// Vanity address params - use `cast create2` to find salt (salt must change for each deployment)
bytes32 constant SEPOLIA_SALT_SYSTEMCOIN = 0x46320220579d213d0446f6f1fb03407627be45d5215e7d705569a5346288aa97;
bytes32 constant SEPOLIA_SALT_PROTOCOLTOKEN = 0xc262cd83fe003707ee84344a60b91f7fe4ecf9f2699c79415942c5277e5a3985;
bytes32 constant SEPOLIA_SALT_VAULT721 = 0x2bfa56b0ce602655b440d2aa008f0900d12ef45823378bf9cb8d32eba74439c3;

// Camelot Relayer (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_CAMELOT_RELAYER_FACTORY = 0x92Bfb4D96f0b8dcA8F6e5E0fc4713DEa8243d9D6;
address constant SEPOLIA_CAMELOT_RELAYER = 0x1217755f6F4Ed87c70336ae958424bEB001c9035;

// Chainlink Relayer (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_CHAINLINK_RELAYER_FACTORY = 0x321D55f347095cdA4Ec8d10B63cD099396D1eb29;
address constant SEPOLIA_CHAINLINK_RELAYER = 0x1217755f6F4Ed87c70336ae958424bEB001c9035;

// Denominated Oracle (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_DENOMINATED_ORACLE_FACTORY = 0xaF3A59b1794d0E51197CED02AEb87E14DEf07aCf;

// SystemCoinOracle (pre-deployed @ sol 0.7.6 as denominatedOracle)
address constant SEPOLIA_SYSTEM_COIN_ORACLE_X = 0x571b1fd22DfB354E704b206f756aC8635A431a2a;
address constant SEPOLIA_SYSTEM_COIN_ORACLE = 0x4cc0B8F7867a44023af3C2086c3F7d1e3384AC75;

// Algebra protocol (not deployed by Camelot)
address constant SEPOLIA_CAMELOT_AMM_FACTORY = 0x21852176141b8D139EC5D3A1041cdC31F0F20b94;
address constant SEPOLIA_CAMELOT_POOL = 0x970582952efd504062eb836faA975C4f40fAf3CA;

// Chainlink feeds
address constant SEPOLIA_CHAINLINK_ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
address constant SEPOLIA_CHAINLINK_ARB_USD_FEED = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;

// Unverified WETH token
address constant SEPOLIA_WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

// --- ARB Mainnet ---

// Create2 Factory
address constant MAINNET_CREATE2FACTORY = address(0);

// Protocol Token
address constant MAINNET_PROTOCOL_TOKEN = address(0);

// Governance Settings
uint256 constant MAINNET_INIT_VOTING_DELAY = 332_308;
uint256 constant MAINNET_INIT_VOTING_PERIOD = 2_326_156;
uint256 constant MAINNET_INIT_PROP_THRESHOLD = 0;

// Deployment params
address constant MAINNET_DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;
address constant MAINNET_SAFE = 0x8516B2319b0541E0253b866557929FF7B76027ba; // set this before mainnet deployment
uint256 constant AIRDROP_AMOUNT = 10_000e18; // 10k tokens
uint256 constant MIN_DELAY = 3 days; // timelock for governor
uint256 constant ORACLE_INTERVAL_PROD = 1 hours;

// Vanity address params - use `cast create2` to find salt
bytes32 constant MAINNET_SALT_SYSTEMCOIN = bytes32(uint256(0x1));
bytes32 constant MAINNET_SALT_PROTOCOLTOKEN = bytes32(uint256(0x1));
bytes32 constant MAINNET_SALT_VAULT721 = bytes32(uint256(0x1));

// Camelot Relayer (pre-deployed @ sol 0.7.6)
address constant MAINNET_CAMELOT_RELAYER_FACTORY = address(0);
address constant MAINNET_CAMELOT_RELAYER = address(0);

// Camelot Protocol
address constant MAINNET_CAMELOT_AMM_FACTORY = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

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

// WETH token
address constant MAINNET_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
