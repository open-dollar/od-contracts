// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// for Goerli, add oracleForTestnet auth
address constant GOVERNOR_DAO = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
address constant J = 0xcb81A76a565aC4870EDA5B0e32c5a0D2ec734174;
address constant P = 0xC295763Eed507d4A0f8B77241c03dd3354781a15;

address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
address constant GOERLI_UNISWAP_V3_FACTORY = 0x4893376342d5D7b3e31d4184c08b265e5aB2A3f6;

address constant CAMELOT_FACTORY = 0x6EcCab422D763aC031210895C81787E87B43A652;
address constant GOERLI_CAMELOT_FACTORY = 0x659fd9F4536f540bd051c2739Fc8b8e9355E5042;

// --- ARB Goerli ---
address constant ARB_GOERLI_CHAINLINK_ETH_USD_FEED = 0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08; // ETH to USD
address constant ARB_GOERLI_CHAINLINK_FTRG_USD_FEED = 0x2eE9BFB2D319B31A573EA15774B755715988E99D; // ARB to USD
address constant ARB_GOERLI_CHAINLINK_BTC_USD_FEED = 0x6550bc2301936011c1334555e62A87705A81C12C; // ARB to USD

address constant ARB_GOERLI_WETH = 0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f;
address constant ARB_GOERLI_GOV_TOKEN = 0x0Ed89D4655b2fE9f99EaDC3116b223527165452D;

// --- ARB Mainnet ---
address constant ARB_GOV = 0x912CE59144191C1204E64559FE8253a0e49E6548;
address constant ARB_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant ARB_WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
address constant ARB_WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
address constant ARB_RETH = 0xB766039cc6DB368759C1E56B79AFfE831d0Cc507;

// to USD
address constant ARB_CHAINLINK_ARB_USD_FEED = 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6;
address constant ARB_CHAINLINK_ETH_USD_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
address constant ARB_CHAINLINK_WBTC_USD_FEED = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;

// to ETH
address constant ARB_CHAINLINK_WSTETH_ETH_FEED = 0xB1552C5e96B312d0Bf8b554186F846C40614a540;
address constant ARB_CHAINLINK_RETH_ETH_FEED = 0xF3272CAfe65b190e76caAF483db13424a3e23dD2; // blue rating; not for general use

// TODO: Remove & update oracle tests
// KEEP TO PASS ORACLE TESTS UNTIL NOT NEEDED
// --- OP Mainnet ---
address constant OP_WETH = 0x4200000000000000000000000000000000000006;
address constant OP_OPTIMISM = 0x4200000000000000000000000000000000000042;
address constant OP_WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
address constant OP_WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;

address constant OP_CHAINLINK_ETH_USD_FEED = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
address constant OP_CHAINLINK_WSTETH_ETH_FEED = 0x524299Ab0987a7c4B3c8022a35669DdcdC715a10;

// --- OP Goerli ---
address constant OP_GOERLI_CHAINLINK_ETH_USD_FEED = 0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8;
address constant OP_GOERLI_CHAINLINK_BTC_USD_FEED = 0xC16679B963CeB52089aD2d95312A5b85E318e9d2;
