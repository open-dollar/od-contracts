// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Script.sol';
import '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import '@script/Registry.s.sol';
import '@libraries/Math.sol';

abstract contract Deploy is Script, Contracts {
  uint256 public chainId;
  address public deployer;
  uint256 internal _deployerPk = 69; // for tests

  bytes32[] public collateralTypes;
  mapping(bytes32 => CollateralParams) public collateralParams;

  function _setupEnvironment() internal virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(_deployerPk);

    // Environment may be different for each network
    _setupEnvironment();

    // Common deployment routine for all networks
    deployAndSetup(
      GlobalParams({
        debtAuctionMintedTokens: INITIAL_DEBT_AUCTION_MINTED_TOKENS,
        bidAuctionSize: BID_AUCTION_SIZE,
        surplusAmount: SURPLUS_AUCTION_SIZE,
        globalDebtCeiling: GLOBAL_DEBT_CEILING,
        globalStabilityFee: GLOBAL_STABILITY_FEE,
        maxSecondaryReceivers: MAX_SECONDARY_RECEIVERS,
        surplusAuctionBidReceiver: SURPLUS_AUCTION_BID_RECEIVER,
        surplusAuctionRecyclingPercentage: SURPLUS_AUCTION_RECYCLING_PERCENTAGE
      })
    );

    deployPIDController(
      PIDParams({
        proportionalGain: PID_PROPORTIONAL_GAIN,
        integralGain: PID_INTEGRAL_GAIN,
        noiseBarrier: PID_NOISE_BARRIER,
        perSecondCumulativeLeak: PID_PER_SECOND_CUMULATIVE_LEAK,
        feedbackOutputLowerBound: PID_FEEDBACK_OUTPUT_LOWER_BOUND,
        feedbackOutputUpperBound: PID_FEEDBACK_OUTPUT_UPPER_BOUND,
        periodSize: PID_PERIOD_SIZE,
        updateRate: PID_UPDATE_RATE
      })
    );
    vm.stopBroadcast();

    // Loop through the collateral types configured in the environment
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      if (_cType == ETH_A) deployETHCollateral(collateralParams[_cType]);
      else deployTokenCollateral(collateralParams[_cType]);
    }
  }

  function deployETHCollateral(CollateralParams memory _params) public {
    vm.startBroadcast(_deployerPk);

    // deploy ETHJoin and CollateralAuctionHouse
    ethJoin = new ETHJoin(address(safeEngine), ETH_A);
    collateralAuctionHouse[ETH_A] = new CollateralAuctionHouse({
        _safeEngine: address(safeEngine), 
        _liquidationEngine: address(liquidationEngine), 
        _collateralType: ETH_A
        });

    collateralJoin[ETH_A] = CollateralJoin(address(ethJoin));

    _setupCollateral(_params);
    vm.stopBroadcast();
  }

  function deployTokenCollateral(CollateralParams memory _params) public {
    vm.startBroadcast(_deployerPk);

    // deploy Collateral, CollateralJoin and CollateralAuctionHouse
    collateral[_params.name] = new ERC20ForTest(); // TODO: replace for token
    collateralJoin[_params.name] = new CollateralJoin({
        _safeEngine: address(safeEngine), 
        _cType: _params.name, 
        _collateral: address(collateral[_params.name])
        });
    collateralAuctionHouse[_params.name] = new CollateralAuctionHouse({
        _safeEngine: address(safeEngine), 
        _liquidationEngine: address(liquidationEngine), 
        _collateralType: _params.name
        });

    _setupCollateral(_params);
    vm.stopBroadcast();
  }

  function revoke() public {
    vm.startBroadcast(deployer);

    // base contracts
    safeEngine.removeAuthorization(deployer);
    liquidationEngine.removeAuthorization(deployer);
    accountingEngine.removeAuthorization(deployer);
    oracleRelayer.removeAuthorization(deployer);

    // tax
    taxCollector.removeAuthorization(deployer);
    stabilityFeeTreasury.removeAuthorization(deployer);

    // tokens
    coin.removeAuthorization(deployer);
    protocolToken.removeAuthorization(deployer);

    // token adapters
    coinJoin.removeAuthorization(deployer);
    ethJoin.removeAuthorization(deployer);
    collateralJoin[WSTETH].removeAuthorization(deployer);

    // auction houses
    surplusAuctionHouse.removeAuthorization(deployer);
    debtAuctionHouse.removeAuthorization(deployer);

    // collateral auction houses
    collateralAuctionHouse[ETH_A].removeAuthorization(deployer);
    collateralAuctionHouse[WSTETH].removeAuthorization(deployer);

    vm.stopBroadcast();
  }

  function deployAndSetup(GlobalParams memory _params) public {
    // deploy Tokens
    coin = new Coin('HAI Index Token', 'HAI', chainId);
    protocolToken = new Coin('Protocol Token', 'KITE', chainId);

    // deploy Base contracts
    safeEngine = new SAFEEngine();
    oracleRelayer = new OracleRelayer(address(safeEngine));
    taxCollector = new TaxCollector(address(safeEngine));
    liquidationEngine = new LiquidationEngine(address(safeEngine));

    coinJoin = new CoinJoin(address(safeEngine), address(coin));
    surplusAuctionHouse =
      new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _params.surplusAuctionRecyclingPercentage);
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken));

    accountingEngine =
      new AccountingEngine(address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse));

    stabilityFeeTreasury = new StabilityFeeTreasury(
          address(safeEngine),
          address(accountingEngine),
          address(coinJoin)
        );

    // TODO: deploy PostSettlementSurplusAuctionHouse & SettlementSurplusAuctioneer
    globalSettlement = new GlobalSettlement();

    // setup registry
    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(accountingEngine));
    liquidationEngine.modifyParameters('accountingEngine', abi.encode(accountingEngine));

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
    coin.addAuthorization(address(coinJoin)); // mint

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

    // setup params
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(_params.globalDebtCeiling));
    taxCollector.modifyParameters('globalStabilityFee', abi.encode(_params.globalStabilityFee));
    accountingEngine.modifyParameters('debtAuctionMintedTokens', abi.encode(_params.debtAuctionMintedTokens));
    accountingEngine.modifyParameters('debtAuctionBidSize', abi.encode(_params.bidAuctionSize));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(_params.surplusAmount));
    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(_params.surplusAuctionBidReceiver));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(_params.maxSecondaryReceivers));
  }

  function _setupCollateral(CollateralParams memory _params) internal {
    safeEngine.addAuthorization(address(collateralJoin[_params.name]));

    oracleRelayer.modifyParameters(_params.name, 'oracle', abi.encode(_params.oracle));

    safeEngine.initializeCollateralType(_params.name);
    taxCollector.initializeCollateralType(_params.name);

    collateralAuctionHouse[_params.name].addAuthorization(address(liquidationEngine));
    liquidationEngine.addAuthorization(address(collateralAuctionHouse[_params.name]));

    // setup registry
    collateralAuctionHouse[_params.name].modifyParameters('oracleRelayer', abi.encode(oracleRelayer));
    collateralAuctionHouse[_params.name].modifyParameters('collateralFSM', abi.encode(_params.oracle));
    liquidationEngine.modifyParameters(
      _params.name, 'collateralAuctionHouse', abi.encode(collateralAuctionHouse[_params.name])
    );
    liquidationEngine.modifyParameters(_params.name, 'liquidationPenalty', abi.encode(_params.liquidationPenalty));
    liquidationEngine.modifyParameters(_params.name, 'liquidationQuantity', abi.encode(_params.liquidationQuantity));

    // setup params
    safeEngine.modifyParameters(_params.name, 'debtCeiling', abi.encode(_params.debtCeiling));
    taxCollector.modifyParameters(_params.name, 'stabilityFee', abi.encode(_params.stabilityFee));
    taxCollector.taxSingle(_params.name);

    taxCollector.modifyParameters(
      _params.name,
      'secondaryTaxReceiver',
      abi.encode(
        ITaxCollector.TaxReceiver({
          receiver: address(stabilityFeeTreasury),
          canTakeBackTax: false,
          taxPercentage: uint128(_params.percentageOfStabilityFeeToTreasury)
        })
      )
    );
    oracleRelayer.modifyParameters(_params.name, 'safetyCRatio', abi.encode(_params.safetyCRatio));
    oracleRelayer.modifyParameters(_params.name, 'liquidationCRatio', abi.encode(_params.liquidationRatio));

    // setup global settlement
    collateralAuctionHouse[_params.name].addAuthorization(address(globalSettlement)); // terminateAuctionPrematurely

    // setup initial price
    oracleRelayer.updateCollateralPrice(_params.name);
  }

  function deployPIDController(PIDParams memory _params) public {
    pidController = new PIDController({
      _kp: _params.proportionalGain,
      _ki: _params.integralGain,
      _perSecondCumulativeLeak: _params.perSecondCumulativeLeak,
      _integralPeriodSize: _params.periodSize, // TODO: rename ips to ps
      _noiseBarrier: _params.noiseBarrier,
      _feedbackOutputUpperBound: _params.feedbackOutputUpperBound,
      _feedbackOutputLowerBound: _params.feedbackOutputLowerBound,
      _importedState: IPIDController.DeviationObservation(0,0,0)
    });

    pidRateSetter = new PIDRateSetter({
     _oracleRelayer: address(oracleRelayer),
     _oracle: address(oracle[HAI]),
     _pidCalculator: address(pidController),
     _updateRateDelay: _params.updateRate
    });

    // setup registry
    pidController.modifyParameters('seedProposer', abi.encode(pidRateSetter));

    // auth
    oracleRelayer.addAuthorization(address(pidRateSetter));

    // initialize
    pidRateSetter.updateRate();
  }
}

contract DeployMainnet is Deploy {
  function setUp() public {
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

    oracle[ETH_A] = new DelayedOracle(_ethUSDPriceFeed, 1 hours);
    oracle[WSTETH] = new DelayedOracle(_wstethUSDPriceFeed, 1 hours);

    oracle[HAI] = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD

    collateralTypes.push(ETH_A);
    collateralParams[ETH_A] = CollateralParams({
      name: ETH_A,
      oracle: oracle[ETH_A],
      liquidationPenalty: ETH_A_LIQUIDATION_PENALTY,
      liquidationQuantity: ETH_A_LIQUIDATION_QUANTITY,
      debtCeiling: ETH_A_DEBT_CEILING,
      safetyCRatio: ETH_A_SAFETY_C_RATIO,
      liquidationRatio: ETH_A_LIQUIDATION_RATIO,
      stabilityFee: ETH_A_STABILITY_FEE,
      percentageOfStabilityFeeToTreasury: PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
    });

    collateralTypes.push(WSTETH);
    collateralParams[WSTETH] = CollateralParams({
      name: WSTETH,
      oracle: oracle[WSTETH],
      liquidationPenalty: TKN_LIQUIDATION_PENALTY,
      liquidationQuantity: TKN_LIQUIDATION_QUANTITY,
      debtCeiling: TKN_DEBT_CEILING,
      safetyCRatio: TKN_SAFETY_C_RATIO,
      liquidationRatio: TKN_LIQUIDATION_RATIO,
      stabilityFee: TKN_STABILITY_FEE,
      percentageOfStabilityFeeToTreasury: PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
    });
  }
}

contract DeployGoerli is Deploy {
  function setUp() public {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    chainId = 420;
  }

  function _setupEnvironment() internal virtual override {
    // Setup oracle feeds
    oracle[HAI] = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD

    IBaseOracle _ethUSDPriceFeed = new ChainlinkRelayer(OP_GOERLI_CHAINLINK_ETH_USD_FEED, 1 hours);
    oracle[ETH_A] = new DelayedOracle(_ethUSDPriceFeed, 1 hours);

    // Setup collateral params
    collateralTypes.push(ETH_A);
    collateralParams[ETH_A] = CollateralParams({
      name: ETH_A,
      oracle: oracle[ETH_A],
      liquidationPenalty: ETH_A_LIQUIDATION_PENALTY,
      liquidationQuantity: ETH_A_LIQUIDATION_QUANTITY,
      debtCeiling: ETH_A_DEBT_CEILING,
      safetyCRatio: ETH_A_SAFETY_C_RATIO,
      liquidationRatio: ETH_A_LIQUIDATION_RATIO,
      stabilityFee: ETH_A_STABILITY_FEE,
      percentageOfStabilityFeeToTreasury: PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
    });
  }
}
