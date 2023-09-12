// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import '@script/Registry.s.sol';
import '@script/Params.s.sol';

import {Script} from 'forge-std/Script.sol';
import {Common} from '@script/Common.s.sol';
import {GoerliParams} from '@script/GoerliParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';

abstract contract Deploy is Common, Script {
  function setupEnvironment() public virtual {}
  function setupPostEnvironment() public virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(deployer);

    //print the commit hash
    string[] memory inputs = new string[](3);
    inputs[0] = "git";
    inputs[1] = "rev-parse";
    inputs[2] = "HEAD";

    bytes memory res = vm.ffi(inputs);

    // Deploy oracle factories used to setup the environment
    deployOracleFactories();

    // Environment may be different for each network
    setupEnvironment();

    // Common deployment routine for all networks
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

    // Deploy contracts related to the SafeManager usecase
    deployProxyContracts(address(safeEngine));

    address[] memory t = new address[](3);
    t[0] = H;
    t[1] = J;
    t[2] = P;

    mintAirdrop(t);
    deployGovernor(address(protocolToken), t, H);
    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    if (delegate == address(0)) {
      _revokeAllTo(governor);
    } else if (delegate == deployer) {
      _delegateAllTo(governor);
    } else {
      _delegateAllTo(delegate);
      _revokeAllTo(governor);
    }

    vm.stopBroadcast();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('ARB_MAINNET_DEPLOYER_PK'));
    chainId = 42_161;
  }

  function setupEnvironment() public virtual override updateParams {
    // Setup oracle feeds
    IBaseOracle _ethUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(ARB_CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_PROD);
    IBaseOracle _wstethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(ARB_CHAINLINK_WSTETH_ETH_FEED, ORACLE_INTERVAL_PROD);

    IBaseOracle _wstethUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _wstethETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    systemCoinOracle = new OracleForTest(OD_INITIAL_PRICE); // 1 OD = 1 USD
    delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, ORACLE_INTERVAL_PROD);

    collateral[WETH] = IERC20Metadata(ARB_WETH);
    collateral[WSTETH] = IERC20Metadata(ARB_WSTETH);

    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeployGoerli is GoerliParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('ARB_GOERLI_DEPLOYER_PK'));
    chainId = 421_613;
  }

  function setupEnvironment() public virtual override updateParams {
    // Setup oracle feeds

    systemCoinOracle = new OracleForTestnet(OD_INITIAL_PRICE); // 1 OD = 1 USD

    // WETH
    collateral[WETH] = IERC20Metadata(ARB_GOERLI_WETH);
    IBaseOracle _ethUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(ARB_GOERLI_CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_TEST); // live feed

    // OP
    collateral[FTRG] = IERC20Metadata(ARB_GOERLI_GOV_TOKEN);
    OracleForTestnet _opETHPriceFeed = new OracleForTestnet(ARB_GOERLI_FTRG_ETH_PRICE_FEED); // denominated feed
    IBaseOracle _opUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _opETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    // Test tokens
    collateral[WBTC] = new MintableERC20('Wrapped BTC', 'wBTC', 8);
    collateral[STONES] = new MintableERC20('Stones', 'STN', 3);
    collateral[TOTEM] = new MintableERC20('Totem', 'TTM', 0);

    // BTC: live feed
    IBaseOracle _wbtcUsdOracle =
      chainlinkRelayerFactory.deployChainlinkRelayer(ARB_GOERLI_CHAINLINK_BTC_USD_FEED, ORACLE_INTERVAL_TEST); // live feed

    IBaseOracle _stonesWbtcOracle = new OracleForTestnet(0.001e18); // denominated feed
    IBaseOracle _stonesOracle =
      denominatedOracleFactory.deployDenominatedOracle(_stonesWbtcOracle, _wbtcUsdOracle, false);

    IBaseOracle _totemWethOracle = new OracleForTestnet(1e18); // hardcoded feed
    IBaseOracle _totemOracle =
      denominatedOracleFactory.deployDenominatedOracle(_totemWethOracle, _ethUSDPriceFeed, false);

    delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[FTRG] = delayedOracleFactory.deployDelayedOracle(_opUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[WBTC] = delayedOracleFactory.deployDelayedOracle(_wbtcUsdOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[STONES] = delayedOracleFactory.deployDelayedOracle(_stonesOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[TOTEM] = delayedOracleFactory.deployDelayedOracle(_totemOracle, ORACLE_INTERVAL_TEST);

    // Setup collateral types
    collateralTypes.push(WETH);
    collateralTypes.push(FTRG);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);
  }

  function setupPostEnvironment() public virtual override updateParams {
    // Setup deviated oracle
    systemCoinOracle = new DeviatedOracle({
      _symbol: 'HAI/USD',
      _oracleRelayer: address(oracleRelayer),
      _deviation: OP_GOERLI_HAI_PRICE_DEVIATION
    });

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));
  }
}
