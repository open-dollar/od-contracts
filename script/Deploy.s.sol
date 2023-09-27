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
  function mintAirdrop() public virtual {}
  function deployGovernor() public virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(deployer);

    // set governor to deployer during deployment
    governor = deployer;
    delegate = address(0);

    //print the commit hash
    string[] memory inputs = new string[](3);
    inputs[0] = 'git';
    inputs[1] = 'rev-parse';
    inputs[2] = 'HEAD';

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

    // Mint initial ODG airdrop
    mintAirdrop();

    // Deploy DAO Governor
    deployGovernor();

    // Deploy contracts related to the SafeManager usecase
    deployProxyContracts();

    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    // set governor to DAO
    governor = vault721.governor();
    delegate = address(0);

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

  function mintAirdrop() public virtual override {
    require(DAO_SAFE != address(0), 'DAO zeroAddress');
    protocolToken.mint(DAO_SAFE, AIRDROP_AMOUNT);
  }

  function deployGovernor() public virtual override {
    require(DAO_SAFE != address(0), 'DAO zeroAddress');
    address[] memory members = new address[](1);
    members[0] = DAO_SAFE;

    timelockController = new TimelockController(MIN_DELAY, members, members, TIMELOCK_ADMIN);
    odGovernor = new ODGovernor(address(protocolToken), timelockController);
  }

  function setupEnvironment() public virtual override updateParams {
    // Setup oracle feeds

    // TODO: change price feed
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
    // delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, ORACLE_INTERVAL_PROD);

    // collateral[WETH] = IERC20Metadata(ARB_WETH);
    collateral[WSTETH] = IERC20Metadata(ARB_WSTETH);

    // collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeployGoerli is GoerliParams, Deploy {
  IBaseOracle public chainlinkEthUSDPriceFeed;

  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('ARB_GOERLI_DEPLOYER_PK'));
    chainId = 421_613;
  }

  function mintAirdrop() public virtual override {
    protocolToken.mint(H, AIRDROP_AMOUNT / 3);
    protocolToken.mint(J, AIRDROP_AMOUNT / 3);
    protocolToken.mint(P, AIRDROP_AMOUNT / 3);
  }

  function deployGovernor() public virtual override {
    address[] memory members = new address[](3);
    members[0] = H;
    members[1] = J;
    members[2] = P;

    timelockController = new TimelockController(MIN_DELAY_GOERLI, members, members, TIMELOCK_ADMIN);
    odGovernor = new ODGovernor(address(protocolToken), timelockController);
  }

  function setupEnvironment() public virtual override updateParams {
    // Setup oracle feeds

    // OD
    systemCoinOracle = new OracleForTestnet(OD_INITIAL_PRICE); // 1 OD = 1 USD 'OD / USD'

    // WSTETH
    collateral[WSTETH] = IERC20Metadata(ARB_GOERLI_WETH);
    chainlinkEthUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(ARB_GOERLI_CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_TEST); // live feed

    // ARB
    collateral[ARB] = IERC20Metadata(ARB_GOERLI_GOV_TOKEN);
    OracleForTestnet _opETHPriceFeed = new OracleForTestnet(ARB_GOERLI_FTRG_ETH_PRICE_FEED); // denominated feed 'ARB / ETH'
    IBaseOracle _opUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _opETHPriceFeed,
      _denominationPriceSource: chainlinkEthUSDPriceFeed,
      _inverted: false
    });

    // Test tokens
    collateral[CBETH] = new MintableERC20('Wrapped BTC', 'wBTC', 8);
    collateral[RETH] = new MintableERC20('Stones', 'STN', 3);
    collateral[MAGIC] = new MintableERC20('Totem', 'TTM', 0);

    // BTC: live feed
    IBaseOracle _wbtcUsdOracle =
      chainlinkRelayerFactory.deployChainlinkRelayer(ARB_GOERLI_CHAINLINK_BTC_USD_FEED, ORACLE_INTERVAL_TEST); // live feed

    IBaseOracle _stonesWbtcOracle = new OracleForTestnet(0.001e18); // denominated feed 'STN / BTC'
    IBaseOracle _stonesOracle =
      denominatedOracleFactory.deployDenominatedOracle(_stonesWbtcOracle, _wbtcUsdOracle, false);

    IBaseOracle _totemWethOracle = new OracleForTestnet(1e18); // hardcoded feed 'TTM'
    IBaseOracle _totemOracle =
      denominatedOracleFactory.deployDenominatedOracle(_totemWethOracle, chainlinkEthUSDPriceFeed, false);

    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(chainlinkEthUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_opUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[CBETH] = delayedOracleFactory.deployDelayedOracle(_wbtcUsdOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_stonesOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[MAGIC] = delayedOracleFactory.deployDelayedOracle(_totemOracle, ORACLE_INTERVAL_TEST);

    // Setup collateral types
    collateralTypes.push(WSTETH);
    collateralTypes.push(ARB);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);
    collateralTypes.push(MAGIC);
  }

  function setupPostEnvironment() public virtual override updateParams {
    // deploy Camelot liquidity pool to create market price for OD
    ICamelotV3Factory(GOERLI_CAMELOT_V3_FACTORY).createPool(address(systemCoin), ARB_GOERLI_WETH);

    // TODO: how to set initial price of pool

    // deploy Camelot relayer to retrieve price from Camelot pool
    IBaseOracle _odWethOracle =
      camelotRelayerFactory.deployCamelotRelayer(address(systemCoin), ARB_GOERLI_WETH, uint32(ORACLE_INTERVAL_TEST));

    // deploy denominated oracle of OD/WSTETH denominated against ETH/USD
    systemCoinOracle = denominatedOracleFactory.deployDenominatedOracle(_odWethOracle, chainlinkEthUSDPriceFeed, false);

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));
  }
}
