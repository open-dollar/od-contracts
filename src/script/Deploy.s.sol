// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {Script} from 'forge-std/Script.sol';
import {
  Params,
  ParamSetter,
  HAI,
  WETH,
  ETH_A,
  WSTETH,
  OP,
  SURPLUS_AUCTION_BID_RECEIVER,
  HAI_INITIAL_PRICE
} from '@script/Params.s.sol';
import {GoerliParams} from '@script/GoerliParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';
import '@script/Registry.s.sol';

abstract contract Deploy is Params, Script, Contracts {
  uint256 public chainId;
  uint256 internal _deployerPk = 69; // for tests

  function _setupEnvironment() internal virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(_deployerPk);

    // Environment may be different for each network
    _setupEnvironment();

    // Common deployment routine for all networks
    deployContracts();

    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      if (_cType == ETH_A) deployEthCollateralContracts();
      else deployCollateralContracts(_cType);
    }

    // Get parameters from Params.s.sol
    _getEnvironmentParams();

    _setupContracts();
    deployPIDController();

    // Loop through the collateral types configured in the environment
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      _setupCollateral(_cType);
    }

    revokeTo(governor);
    vm.stopBroadcast();
  }

  function deployEthCollateralContracts() public {
    // deploy ETHJoin and CollateralAuctionHouse
    // NOTE: deploying ETHJoinForTest to make it work with current tests
    ethJoin = new ETHJoinForTest(address(safeEngine), ETH_A);
    collateralAuctionHouse[ETH_A] = new CollateralAuctionHouse({
        _safeEngine: address(safeEngine), 
        _liquidationEngine: address(liquidationEngine), 
        _collateralType: ETH_A,
        _cahParams: _collateralAuctionHouseSystemCoinParams,
        _cahCParams: _collateralAuctionHouseCParams[ETH_A]
        });

    collateralJoin[ETH_A] = CollateralJoin(address(ethJoin));
  }

  function deployCollateralContracts(bytes32 _cType) public {
    // deploy Collateral, CollateralJoin and CollateralAuctionHouse
    collateralJoin[_cType] = new CollateralJoin({
        _safeEngine: address(safeEngine), 
        _cType: _cType, 
        _collateral: address(collateral[_cType])
        });

    collateralAuctionHouse[_cType] = new CollateralAuctionHouse({
        _safeEngine: address(safeEngine), 
        _liquidationEngine: address(liquidationEngine), 
        _collateralType: _cType,
        _cahParams: _collateralAuctionHouseSystemCoinParams,
        _cahCParams: _collateralAuctionHouseCParams[_cType]
        });
  }

  function revokeTo(address _governor) public {
    if (_governor == deployer || _governor == address(0)) return;

    // base contracts
    safeEngine.addAuthorization(_governor);
    safeEngine.removeAuthorization(deployer);
    liquidationEngine.addAuthorization(_governor);
    liquidationEngine.removeAuthorization(deployer);
    accountingEngine.addAuthorization(_governor);
    accountingEngine.removeAuthorization(deployer);
    oracleRelayer.addAuthorization(_governor);
    oracleRelayer.removeAuthorization(deployer);

    // auction houses
    surplusAuctionHouse.addAuthorization(_governor);
    surplusAuctionHouse.removeAuthorization(deployer);
    debtAuctionHouse.addAuthorization(_governor);
    debtAuctionHouse.removeAuthorization(deployer);

    // tax
    taxCollector.addAuthorization(_governor);
    taxCollector.removeAuthorization(deployer);
    stabilityFeeTreasury.addAuthorization(_governor);
    stabilityFeeTreasury.removeAuthorization(deployer);

    // tokens
    systemCoin.addAuthorization(_governor); // TODO: rm in production env
    systemCoin.removeAuthorization(deployer);
    protocolToken.addAuthorization(_governor);
    protocolToken.removeAuthorization(deployer);

    // token adapters
    coinJoin.addAuthorization(_governor);
    coinJoin.removeAuthorization(deployer);

    if (address(ethJoin) != address(0)) {
      ethJoin.addAuthorization(_governor);
      ethJoin.removeAuthorization(deployer);
    }
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      collateralJoin[_cType].addAuthorization(_governor);
      collateralJoin[_cType].removeAuthorization(deployer);
      collateralAuctionHouse[_cType].addAuthorization(_governor);
      collateralAuctionHouse[_cType].removeAuthorization(deployer);
    }
  }

  function deployContracts() public {
    // deploy Tokens
    systemCoin = new SystemCoin('HAI Index Token', 'HAI');
    protocolToken = new ProtocolToken('Protocol Token', 'KITE');

    // deploy Base contracts
    safeEngine = new SAFEEngine(_safeEngineParams);

    oracleRelayer = new OracleRelayer(address(safeEngine), _oracleRelayerParams);

    liquidationEngine = new LiquidationEngine(address(safeEngine), _liquidationEngineParams);

    coinJoin = new CoinJoin(address(safeEngine), address(systemCoin));
    surplusAuctionHouse =
      new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _surplusAuctionHouseParams);
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);

    accountingEngine =
    new AccountingEngine(address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse), _accountingEngineParams);

    // TODO: deploy in separate module
    _getEnvironmentParams();
    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);

    stabilityFeeTreasury = new StabilityFeeTreasury(
          address(safeEngine),
          address(accountingEngine),
          address(coinJoin),
          _stabilityFeeTreasuryParams
        );

    _deployGlobalSettlement();
    _deployProxyContracts(address(safeEngine));
  }

  // TODO: deploy PostSettlementSurplusAuctionHouse & SettlementSurplusAuctioneer
  function _deployGlobalSettlement() internal {
    globalSettlement = new GlobalSettlement();

    // setup globalSettlement [auth: disableContract]
    // TODO: add key contracts to constructor
    globalSettlement.modifyParameters('safeEngine', abi.encode(safeEngine));
    safeEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('liquidationEngine', abi.encode(liquidationEngine));
    liquidationEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('stabilityFeeTreasury', abi.encode(stabilityFeeTreasury));
    stabilityFeeTreasury.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    accountingEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('oracleRelayer', abi.encode(oracleRelayer));
    oracleRelayer.addAuthorization(address(globalSettlement));
  }

  function _setupContracts() internal {
    // setup registry
    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    liquidationEngine.modifyParameters('accountingEngine', abi.encode(accountingEngine));

    // TODO: change for protocolTokenBidReceiver
    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(SURPLUS_AUCTION_BID_RECEIVER));

    // auth
    safeEngine.addAuthorization(address(oracleRelayer)); // modifyParameters
    safeEngine.addAuthorization(address(coinJoin)); // transferInternalCoins
    safeEngine.addAuthorization(address(taxCollector)); // updateAccumulatedRate
    safeEngine.addAuthorization(address(debtAuctionHouse)); // transferInternalCoins [createUnbackedDebt]
    safeEngine.addAuthorization(address(liquidationEngine)); // confiscateSAFECollateralAndDebt
    surplusAuctionHouse.addAuthorization(address(accountingEngine)); // startAuction
    debtAuctionHouse.addAuthorization(address(accountingEngine)); // startAuction
    accountingEngine.addAuthorization(address(liquidationEngine)); // pushDebtToQueue
    protocolToken.addAuthorization(address(debtAuctionHouse)); // mint
    systemCoin.addAuthorization(address(coinJoin)); // mint
  }

  function _setupCollateral(bytes32 _cType) internal {
    safeEngine.initializeCollateralType(_cType);
    taxCollector.initializeCollateralType(_cType);

    ParamSetter._setupSAFEEngineCollateral(_cType, safeEngine, _safeEngineCParams[_cType]);
    ParamSetter._setupTaxCollectorCollateral(
      _cType, taxCollector, _taxCollectorCParams[_cType], _taxCollectorSecondaryTaxReceiver
    );
    ParamSetter._setupOracleRelayerCollateral(_cType, oracleRelayer, _oracleRelayerCParams[_cType]);
    ParamSetter._setupLiquidationEngineCollateral(_cType, liquidationEngine, _liquidationEngineCParams[_cType]);

    safeEngine.addAuthorization(address(collateralJoin[_cType]));

    collateralAuctionHouse[_cType].addAuthorization(address(liquidationEngine));
    liquidationEngine.addAuthorization(address(collateralAuctionHouse[_cType]));

    // setup registry
    collateralAuctionHouse[_cType].modifyParameters('oracleRelayer', abi.encode(oracleRelayer));
    collateralAuctionHouse[_cType].modifyParameters('collateralFSM', abi.encode(oracle[_cType]));

    // setup params
    taxCollector.taxSingle(_cType);

    // setup global settlement
    collateralAuctionHouse[_cType].addAuthorization(address(globalSettlement)); // terminateAuctionPrematurely

    // setup initial price
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function deployPIDController() public {
    pidController = new PIDController({
      _cGains: _pidControllerGains,
      _pidParams: _pidControllerParams,
      _importedState: IPIDController.DeviationObservation(0,0,0)
    });

    pidRateSetter = new PIDRateSetter({
     _oracleRelayer: address(oracleRelayer),
     _oracle: address(oracle[HAI]),
     _pidCalculator: address(pidController),
     _updateRateDelay: _pidRateSetterParams.updateRateDelay
    });

    // setup registry
    pidController.modifyParameters('seedProposer', abi.encode(pidRateSetter));

    // auth
    oracleRelayer.addAuthorization(address(pidRateSetter));

    // initialize
    pidRateSetter.updateRate();
  }

  function _deployProxyContracts(address _safeEngine) internal {
    dsProxyFactory = new HaiProxyFactory();
    proxyRegistry = new HaiProxyRegistry(address(dsProxyFactory));
    safeManager = new HaiSafeManager(_safeEngine);
    proxyActions = new BasicActions();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
    chainId = 10;
  }

  function _setupEnvironment() internal virtual override {
    // Setup oracle feeds
    IBaseOracle _ethUSDPriceFeed = new ChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, 1 hours);
    IBaseOracle _wstethETHPriceFeed = new ChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, 1 hours);

    IBaseOracle _wstethUSDPriceFeed = new DenominatedOracle({
      _priceSource: _wstethETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    oracle[HAI] = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD
    oracle[WETH] = new DelayedOracle(_ethUSDPriceFeed, 1 hours);
    oracle[WSTETH] = new DelayedOracle(_wstethUSDPriceFeed, 1 hours);

    // TODO: change collateral => ERC20ForTest for IERC20
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = ERC20ForTest(OP_WSTETH);

    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);

    _getEnvironmentParams();
  }
}

contract DeployGoerli is GoerliParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    chainId = 420;
  }

  function _setupEnvironment() internal virtual override {
    // Setup oracle feeds
    oracle[HAI] = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD

    IBaseOracle _ethUSDPriceFeed = new ChainlinkRelayer(OP_GOERLI_CHAINLINK_ETH_USD_FEED, 1 hours);
    OracleForTest _opETHPriceFeed = new OracleForTest(OP_GOERLI_OP_ETH_PRICE_FEED);
    DenominatedOracle _opUSDPriceFeed = new DenominatedOracle({
      _priceSource: _opETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    oracle[WETH] = new DelayedOracle(_ethUSDPriceFeed, 1 hours);
    oracle[OP] = new DelayedOracle(_opUSDPriceFeed, 1 hours);

    collateral[WETH] = IERC20Metadata(OP_GOERLI_WETH);
    collateral[OP] = ERC20ForTest(OP_GOERLI_OPTIMISM);

    // Setup collateral params
    collateralTypes.push(WETH);
    collateralTypes.push(OP);

    _getEnvironmentParams();
  }
}
