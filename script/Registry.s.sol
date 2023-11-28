// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// --- Anvil Local Testnet ---

// Members for governance
address constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
address constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
address constant CHARLOTTE = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

// --- ARB Sepolia Testnet ---

// Deployment params
uint256 constant MIN_DELAY_GOERLI = 1 minutes;
uint256 constant ORACLE_INTERVAL_TEST = 1 minutes;

// Members for governance
address constant H = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
address constant J = 0xcb81A76a565aC4870EDA5B0e32c5a0D2ec734174;
address constant P = 0xC295763Eed507d4A0f8B77241c03dd3354781a15;

// Vanity address params - use `cast create2` to find salt
uint256 constant SEPOLIA_SALT_SYSTEMCOIN = 1;
uint256 constant SEPOLIA_SALT_PROTOCOLTOKEN = 1;
uint256 constant SEPOLIA_SALT_VAULT721 = 1;
address constant SEPOLIA_CREATE2_FACTORY = 0xb9d4cbCcF0152040c3269D9701EE68426196e42a;

// --- ARB Goerli Testnet ---

// Token contracts
address constant GOERLI_WETH = 0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f;
address constant GOERLI_GOV_TOKEN = 0x0Ed89D4655b2fE9f99EaDC3116b223527165452D;
// Chainlink feeds
address constant GOERLI_CHAINLINK_ETH_USD_FEED = 0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08;
address constant GOERLI_CHAINLINK_ARB_USD_FEED = 0x2eE9BFB2D319B31A573EA15774B755715988E99D;
// Liquidity pools
address constant GOERLI_UNISWAP_V3_FACTORY = 0x4893376342d5D7b3e31d4184c08b265e5aB2A3f6;
address constant GOERLI_CAMELOT_V2_FACTORY = 0x659fd9F4536f540bd051c2739Fc8b8e9355E5042;
address constant GOERLI_CAMELOT_V3_FACTORY = 0x5Cd40c7E21A15E7FC2503Fffd77cF70c60628F6C; // AlgebraFactory
address constant GOERLI_CAMELOT_V3_POOLDEPLOYER = 0xe0e840C629402AB33433D00937Fe065634b1B1Af; // AlgebraPoolDeployer

// --- ARB Mainnet ---

// Deployment params
address constant DAO_SAFE = address(0); // set this before mainnet deployment
uint256 constant AIRDROP_AMOUNT = 10_000e18; // 10k tokens
uint256 constant MIN_DELAY = 3 days; // timelock for governor
uint256 constant ORACLE_INTERVAL_PROD = 1 hours;

// Vanity address params - use `cast create2` to find salt
uint256 constant MAINNET_SALT_SYSTEMCOIN = 0;
uint256 constant MAINNET_SALT_PROTOCOLTOKEN = 0;
uint256 constant MAINNET_SALT_VAULT721 = 0;
address constant MAINNET_CREATE2_FACTORY = address(0);

// Token contracts (all 18 decimals)
address constant ARBITRUM_WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
address constant ARBITRUM_ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
address constant ARBITRUM_CBETH = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f;
address constant ARBITRUM_RETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
address constant ARBITRUM_MAGIC = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;

// Chainlink feeds w/ rating
// to USD
address constant CHAINLINK_ARB_USD_FEED = 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6; // green
address constant CHAINLINK_ETH_USD_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // green
address constant CHAINLINK_MAGIC_USD_FEED = 0x47E55cCec6582838E173f252D08Afd8116c2202d; // yellow
// to ETH
address constant CHAINLINK_WSTETH_ETH_FEED = 0xb523AE262D20A936BC152e6023996e46FDC2A95D; // green
address constant CHAINLINK_CBETH_ETH_FEED = 0xa668682974E3f121185a3cD94f00322beC674275; // green
address constant CHAINLINK_RETH_ETH_FEED = 0xF3272CAfe65b190e76caAF483db13424a3e23dD2; // blue

// Liquidity pools
address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
address constant CAMELOT_V2_FACTORY = 0x6EcCab422D763aC031210895C81787E87B43A652;
address constant CAMELOT_V3_FACTORY = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

// for oracle test
address constant WETH = address(0);
address constant WBTC = address(0);

// --- OP Mainnet ---

// TODO: Remove & update oracle tests
// KEEP TO PASS ORACLE TESTS UNTIL NOT NEEDED
address constant OP_WETH = 0x4200000000000000000000000000000000000006;
address constant OP_OPTIMISM = 0x4200000000000000000000000000000000000042;
address constant OP_WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
address constant OP_WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;

address constant OP_CHAINLINK_ETH_USD_FEED = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
address constant OP_CHAINLINK_WSTETH_ETH_FEED = 0x524299Ab0987a7c4B3c8022a35669DdcdC715a10;

// --- OP Goerli ---
address constant OP_GOERLI_CHAINLINK_ETH_USD_FEED = 0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8;
address constant OP_GOERLI_CHAINLINK_BTC_USD_FEED = 0xC16679B963CeB52089aD2d95312A5b85E318e9d2;
