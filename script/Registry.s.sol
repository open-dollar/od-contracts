// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

// --- ARB Sepolia Testnet ---

// Governor
address constant SEPOLIA_TIMELOCK_CONTROLLER = 0xC1b1A32Cb29E441A1a16cC1120aF47f2787D5000;
address constant SEPOLIA_OD_GOVERNOR = 0x69ae232E574352232aB8678869eAA3BEBd885211;

// Create2 Factory
address constant TEST_CREATE2FACTORY = 0xC5f2C81d16764908B18379D95f410912d928Adc2;

// Vault721
uint256 constant BLOCK_DELAY = 3;
uint256 constant TIME_DELAY = 1 hours;

// Tokens
address constant SEPOLIA_PROTOCOL_TOKEN = 0xbbB4f37c787C6ecb0b6b5Fb3F73221aA22fabA70;
address constant SEPOLIA_SYSTEM_COIN = 0x0006d00Ae8375BDb0b10fBb100490CD5504fD802;
uint256 constant AIRDROP_AMOUNT = 10_000_000e18; // 10 million tokens
uint256 constant AIRDROP_RECIPIENTS = 2;

uint256 constant SEPOLIA_INIT_VOTING_DELAY = 5; // 1 min
uint256 constant SEPOLIA_INIT_VOTING_PERIOD = 25; // 5 min
uint256 constant SEPOLIA_INIT_PROP_THRESHOLD = 10_000e18;
uint256 constant SEPOLIA_INIT_VOTE_QUORUM = 3;

// Governance Settings
uint256 constant TEST_INIT_VOTING_DELAY = 1;
uint256 constant TEST_INIT_VOTING_PERIOD = 15;
uint256 constant TEST_INIT_PROP_THRESHOLD = 0;
uint256 constant TEST_INIT_VOTE_QUORUM = 3;

// Deployment params
uint256 constant ORACLE_INTERVAL_TEST = 1 minutes;
uint256 constant SEPOLIA_MIN_DELAY = 1 minutes;

// Members for governance
address constant H = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
address constant J = 0xcb81A76a565aC4870EDA5B0e32c5a0D2ec734174;
address constant P = 0xC295763Eed507d4A0f8B77241c03dd3354781a15;

// Vanity address params - use `cast create2` to find salt (salt must change for each deployment)
bytes32 constant SEPOLIA_SALT_SYSTEMCOIN = bytes32(uint256(0x1a));
bytes32 constant SEPOLIA_SALT_PROTOCOLTOKEN = 0xb05d41f9bf22a7cc22e8d712ee9fb325052e1f1bdf30bbe7ace677e42455c2cf;
bytes32 constant SEPOLIA_SALT_VAULT721 = bytes32(uint256(0x1a));

// Camelot Relayer (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_CAMELOT_RELAYER_FACTORY = 0x7C85Bceb6DE55f317fe846a2e02100Ac84e94167;
address constant SEPOLIA_CAMELOT_RELAYER = 0x1217755f6F4Ed87c70336ae958424bEB001c9035;

// Chainlink Relayer (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_CHAINLINK_RELAYER_FACTORY = 0x67760796Ae4beD0b317ECcd4e482EFca46F10D68;
address constant SEPOLIA_CHAINLINK_RELAYER = 0x1217755f6F4Ed87c70336ae958424bEB001c9035;

// Denominated Oracle (pre-deployed @ sol 0.7.6)
address constant SEPOLIA_DENOMINATED_ORACLE_FACTORY = 0x07ACBf81a156EAe49Eaa0eF80bBAe4E050f6278e;

// SystemCoinOracle (pre-deployed @ sol 0.7.6 as denominatedOracle)
address constant SEPOLIA_SYSTEM_COIN_ORACLE = 0x4cc0B8F7867a44023af3C2086c3F7d1e3384AC75;
address constant SEPOLIA_SYSTEM_COIN_ORACLE_AUDIT = 0x6a8eD000B694c18eA447E6023232FD872A66bA7A;

// Algebra protocol (not deployed by Camelot)
address constant SEPOLIA_CAMELOT_AMM_FACTORY = 0x21852176141b8D139EC5D3A1041cdC31F0F20b94;
address constant SEPOLIA_CAMELOT_POOL = 0x970582952efd504062eb836faA975C4f40fAf3CA;

// Chainlink feeds
address constant SEPOLIA_CHAINLINK_ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
address constant SEPOLIA_CHAINLINK_ARB_USD_FEED = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;

// Unverified WETH token
address constant SEPOLIA_WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

// --- ARB Mainnet ---

// Governor
address constant MAINNET_TIMELOCK_CONTROLLER = 0x7A528eA3E06D85ED1C22219471Cf0b1851943903;
address constant MAINNET_OD_GOVERNOR = 0xf704735CE81165261156b41D33AB18a08803B86F;

address constant MAINNET_SYSTEM_COIN_ORACLE = 0x0Cb5313C825d0F00e9708BA54D906E8975a591aB; // from od-relayer deployment

// Protocol Token
address constant MAINNET_PROTOCOL_TOKEN = 0x000D636bD52BFc1B3a699165Ef5aa340BEA8939c;

// Governance Settings
uint256 constant MAINNET_INIT_VOTING_DELAY = 3600; // 12 hours in blocks
uint256 constant MAINNET_INIT_VOTING_PERIOD = 14_400; // 48 hours in blocks
uint256 constant MAINNET_INIT_PROP_THRESHOLD = 5000 * 1e18; // 5k ODG
uint256 constant MAINNET_INIT_VOTE_QUORUM = 2; // 20k ODG

// Deployment params
address constant MAINNET_TEST_DEPLOYER = 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1;
address constant MAINNET_DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;
address constant MAINNET_SAFE = 0x8516B2319b0541E0253b866557929FF7B76027ba; // set this before mainnet deployment
uint256 constant MAINNET_MIN_DELAY = 3 days; // timelock for tlcGov
uint256 constant ORACLE_INTERVAL_PROD = 1 hours;

// Create2 Factory
address constant MAINNET_CREATE2FACTORY = 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f;

// Vanity address params - Calculate using ComputeAdress.s.sol
bytes32 constant MAINNET_SALT_SYSTEMCOIN = bytes32(uint256(0x1a));
bytes32 constant MAINNET_SALT_PROTOCOLTOKEN = 0xb2c552ad83cd8e190b3d170a646188c6a64fc6dda47a1ae28748fc0f6c53ce65; // 0x000D636bD52BFc1B3a699165Ef5aa340BEA8939c
bytes32 constant MAINNET_SALT_VAULT721 = 0x313ea1c24cc50d612632e9f0d6131525f483a8fbc682fdfd87dabc24fb091325;

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
address constant CHAINLINK_RETH_ETH_FEED = 0xD6aB2298946840262FcC278fF31516D39fF611eF;
address constant CHAINLINK_CBETH_ETH_FEED = 0xa668682974E3f121185a3cD94f00322beC674275;

// Oracle relayers
address constant MAINNET_CHAINLINK_ARB_USD_RELAYER = 0x2635f731BB6981E72F92A781578952450759F762;
address constant MAINNET_CHAINLINK_ETH_USD_RELAYER = 0x3e6C1621f674da311E57646007fBfAd857084383;
address constant MAINNET_DENOMINATED_RETH_USD_ORACLE = 0x2b6b76D9854E9A7189c2F1b496c10043b373e453;
address constant MAINNET_DENOMINATED_WSTETH_USD_ORACLE = 0xD0cf1FfFF3FB90c87210D76DFBc3AcfFd02D6B12;

// --- Anvil Local Testnet ---

// Members for governance
address constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
address constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
address constant CHARLOTTE = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

// WETH token
address constant MAINNET_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
