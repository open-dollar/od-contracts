// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/console2.sol';

import '@script/Contracts.s.sol';
import '@script/Registry.s.sol';
import '@script/Params.s.sol';

import {FixedPointMathLib} from '@isolmate/utils/FixedPointMathLib.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {Script} from 'forge-std/Script.sol';
import {Common} from '@script/Common.s.sol';
import {GoerliParams} from '@script/GoerliParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';
import {IAlgebraPool} from '@interfaces/oracles/IAlgebraPool.sol';
import {Create2Factory} from '@contracts/utils/Create2Factory.sol';

abstract contract Deploy is Common, Script {
  function setupEnvironment() public virtual {}
  function setupPostEnvironment() public virtual {}
  function mintAirdrop() public virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk); // ARB_SEPOLIA_DEPLOYER_PK
    vm.startBroadcast(deployer);

    // set governor to deployer during deployment
    governor = address(0);
    delegate = address(0);

    //print the commit hash
    string[] memory inputs = new string[](3);
    inputs[0] = 'git';
    inputs[1] = 'rev-parse';
    inputs[2] = 'HEAD';

    // bytes memory res = vm.ffi(inputs);

    // Deploy oracle factories used to setup the environment
    deployOracleFactories();

    // Environment may be different for each network
    setupEnvironment();

    // Common deployment routine for all networks
    deployTokenGovernance();
    deployContracts();
    deployTaxModule();
    _setupContracts();

    deployGlobalSettlement();
    _setupGlobalSettlement();

    // PID Controller contracts
    deployPIDController();
    _setupPIDController();

    // Rewarded Actions contracts
    deployJobContracts();
    _setupJobContracts();

    // Deploy collateral contracts
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      if (_cType == ETH_A) deployEthCollateralContracts();
      else deployCollateralContracts(_cType);
      _setupCollateral(_cType);
    }

    // Mint initial ODG airdrop
    mintAirdrop();

    // Deploy contracts related to the SafeManager usecase
    deployProxyContracts();

    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    if (getChainId() == 42_161) {
      // mainnet: revoke deployer, authorize governor
      _revokeAllTo(governor);
    } else {
      // sepolia || anvil: revoke deployer, authorize [H, P, governor]
      _delegateAllTo(H);
      _delegateAllTo(P);
      _revokeAllTo(governor);
    }

    vm.stopBroadcast();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('ARB_MAINNET_DEPLOYER_PK'));
    chainId = 42_161;
    _create2Factory = Create2Factory(MAINNET_CREATE2_FACTORY);
    salt1 = MAINNET_SALT_SYSTEMCOIN;
    salt2 = MAINNET_SALT_PROTOCOLTOKEN;
    salt3 = MAINNET_SALT_VAULT721;
  }

  function mintAirdrop() public virtual override {
    require(DAO_SAFE != address(0), 'DAO zeroAddress');
    protocolToken.mint(DAO_SAFE, AIRDROP_AMOUNT);
  }

  // Setup oracle feeds
  function setupEnvironment() public virtual override updateParams {
    // to USD
    IBaseOracle _ethUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_PROD);

    IBaseOracle _arbUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_ARB_USD_FEED, ORACLE_INTERVAL_PROD);

    IBaseOracle _magicUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_MAGIC_USD_FEED, ORACLE_INTERVAL_PROD);

    // to ETH
    IBaseOracle _wstethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_WSTETH_ETH_FEED, ORACLE_INTERVAL_PROD);

    IBaseOracle _cbethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_CBETH_ETH_FEED, ORACLE_INTERVAL_PROD);

    IBaseOracle _rethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_RETH_ETH_FEED, ORACLE_INTERVAL_PROD);

    // denominations
    IBaseOracle _wstethUSDPriceFeed =
      denominatedOracleFactory.deployDenominatedOracle(_wstethETHPriceFeed, _ethUSDPriceFeed, false);

    IBaseOracle _cbethUSDPriceFeed =
      denominatedOracleFactory.deployDenominatedOracle(_cbethETHPriceFeed, _ethUSDPriceFeed, false);

    IBaseOracle _rethUSDPriceFeed =
      denominatedOracleFactory.deployDenominatedOracle(_rethETHPriceFeed, _ethUSDPriceFeed, false);

    systemCoinOracle = new OracleForTest(OD_INITIAL_PRICE); // 1 OD = 1 USD

    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_arbUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[CBETH] = delayedOracleFactory.deployDelayedOracle(_cbethUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_rethUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[MAGIC] = delayedOracleFactory.deployDelayedOracle(_magicUSDPriceFeed, ORACLE_INTERVAL_PROD);

    collateral[ARB] = IERC20Metadata(ARBITRUM_ARB);
    collateral[WSTETH] = IERC20Metadata(ARBITRUM_WSTETH);
    collateral[CBETH] = IERC20Metadata(ARBITRUM_CBETH);
    collateral[RETH] = IERC20Metadata(ARBITRUM_RETH);
    collateral[MAGIC] = IERC20Metadata(ARBITRUM_MAGIC);

    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);
    collateralTypes.push(MAGIC);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeployGoerli is GoerliParams, Deploy {
  using FixedPointMathLib for uint256;

  IBaseOracle public chainlinkEthUSDPriceFeed;

  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('ARB_SEPOLIA_DEPLOYER_PK'));
    chainId = 421_614;
    _create2Factory = Create2Factory(SEPOLIA_CREATE2_FACTORY);
    salt1 = SEPOLIA_SALT_SYSTEMCOIN;
    salt2 = SEPOLIA_SALT_PROTOCOLTOKEN;
    salt3 = SEPOLIA_SALT_VAULT721;
  }

  function mintAirdrop() public virtual override {
    protocolToken.mint(H, AIRDROP_AMOUNT / 3);
    protocolToken.mint(J, AIRDROP_AMOUNT / 3);
    protocolToken.mint(P, AIRDROP_AMOUNT / 3);
  }

  // Setup oracle feeds
  function setupEnvironment() public virtual override updateParams {
    // OD
    systemCoinOracle = new OracleForTestnet(OD_INITIAL_PRICE); // 1 OD = 1 USD 'OD / USD'

    // Test tokens (various decimals for testing)
    collateral[ARB] = new MintableVoteERC20('Arbitrum', 'ARB', 18);
    collateral[WSTETH] = new MintableERC20('Wrapped liquid staked Ether 2.0', 'wstETH', 8);
    collateral[CBETH] = new MintableERC20('Coinbase Wrapped Staked ETH', 'cbETH', 8);
    collateral[RETH] = new MintableERC20('Rocket Pool ETH', 'rETH', 3);
    collateral[MAGIC] = new MintableERC20('Magic', 'MAGIC', 0);

    // to USD - Sepolia does not have Chainlink feeds now
    chainlinkEthUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(SEPOLIA_CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_TEST);
    // chainlinkEthUSDPriceFeed = new OracleForTestnet(1815e18);

    // to ETH
    OracleForTestnet _arbETHPriceFeed = new OracleForTestnet(GOERLI_ARB_ETH_PRICE_FEED);

    // denominations
    IBaseOracle _arbUSDPriceFeed =
      denominatedOracleFactory.deployDenominatedOracle(_arbETHPriceFeed, chainlinkEthUSDPriceFeed, false);

    IBaseOracle _rethETHOracle = new OracleForTestnet(0.98e18);
    IBaseOracle _rethOracle =
      denominatedOracleFactory.deployDenominatedOracle(_rethETHOracle, chainlinkEthUSDPriceFeed, false);

    IBaseOracle _magicETHOracle = new OracleForTestnet(0.00032e18);
    IBaseOracle _magicOracle =
      denominatedOracleFactory.deployDenominatedOracle(_magicETHOracle, chainlinkEthUSDPriceFeed, false);

    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_arbUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(chainlinkEthUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[CBETH] = delayedOracleFactory.deployDelayedOracle(chainlinkEthUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_rethOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[MAGIC] = delayedOracleFactory.deployDelayedOracle(_magicOracle, ORACLE_INTERVAL_TEST);

    // Setup collateral types
    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);
    collateralTypes.push(MAGIC);
  }

  /**
   * @dev postdeployment moved to od-relayer
   */
  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeployAnvil is GoerliParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('ANVIL_ONE'));
    chainId = 31_337;
  }

  function mintAirdrop() public virtual override {
    protocolToken.mint(ALICE, AIRDROP_AMOUNT / 3);
    protocolToken.mint(BOB, AIRDROP_AMOUNT / 3);
    protocolToken.mint(CHARLOTTE, AIRDROP_AMOUNT / 3);
  }

  // Setup oracle feeds
  function setupEnvironment() public virtual override updateParams {
    // OD
    systemCoinOracle = new OracleForTestnet(OD_INITIAL_PRICE); // 1 OD = 1 USD 'OD / USD'

    // Test tokens
    collateral[ARB] = new MintableVoteERC20('Arbitrum', 'ARB', 18);
    collateral[WSTETH] = new MintableERC20('Wrapped liquid staked Ether 2.0', 'wstETH', 18);
    collateral[CBETH] = new MintableERC20('Coinbase Wrapped Staked ETH', 'cbETH', 18);
    collateral[RETH] = new MintableERC20('Rocket Pool ETH', 'rETH', 18);
    collateral[MAGIC] = new MintableERC20('Magic', 'MAGIC', 18);

    // WSTETH
    IBaseOracle _wstethUSDPriceFeed = new OracleForTestnet(1500e18);

    // ARB
    OracleForTestnet _arbETHPriceFeed = new OracleForTestnet(0.00055e18);
    IBaseOracle _arbOracle =
      denominatedOracleFactory.deployDenominatedOracle(_arbETHPriceFeed, _wstethUSDPriceFeed, false);

    // CBETH
    IBaseOracle _cbethETHPriceFeed = new OracleForTestnet(1e18);
    IBaseOracle _cbethOracle =
      denominatedOracleFactory.deployDenominatedOracle(_cbethETHPriceFeed, _wstethUSDPriceFeed, false);

    // RETH
    IBaseOracle _rethETHOracle = new OracleForTestnet(0.98e18);
    IBaseOracle _rethOracle =
      denominatedOracleFactory.deployDenominatedOracle(_rethETHOracle, _wstethUSDPriceFeed, false);

    // MAGIC
    IBaseOracle _magicETHOracle = new OracleForTestnet(0.00032e18);
    IBaseOracle _magicOracle =
      denominatedOracleFactory.deployDenominatedOracle(_magicETHOracle, _wstethUSDPriceFeed, false);

    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_arbOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[CBETH] = delayedOracleFactory.deployDelayedOracle(_cbethOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_rethOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[MAGIC] = delayedOracleFactory.deployDelayedOracle(_magicOracle, ORACLE_INTERVAL_TEST);

    // Setup collateral types
    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);
    collateralTypes.push(MAGIC);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}
