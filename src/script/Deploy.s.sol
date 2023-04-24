// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Script.sol';
import '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import '@libraries/Math.sol';

contract Deploy is Script, Contracts {
  uint256 public chainId;
  address public deployer;
  uint256 internal _deployerPk = 69; // for tests

  function run() public {
    deployer = vm.addr(_deployerPk);

    deployAndSetup(
      GlobalParams({
        initialDebtAuctionMintedTokens: INITIAL_DEBT_AUCTION_MINTED_TOKENS,
        bidAuctionSize: BID_AUCTION_SIZE,
        surplusAuctionAmountToSell: SURPLUS_AUCTION_SIZE,
        globalDebtCeiling: GLOBAL_DEBT_CEILING,
        globalStabilityFee: GLOBAL_STABILITY_FEE,
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
      }),
      HAI_INITIAL_PRICE
    );

    deployETHCollateral(
      CollateralParams({
        name: ETH_A,
        liquidationPenalty: ETH_A_LIQUIDATION_PENALTY,
        liquidationQuantity: ETH_A_LIQUIDATION_QUANTITY,
        debtCeiling: ETH_A_DEBT_CEILING,
        safetyCRatio: ETH_A_SAFETY_C_RATIO,
        liquidationRatio: ETH_A_LIQUIDATION_RATIO,
        stabilityFee: ETH_A_STABILITY_FEE
      }),
      TEST_ETH_PRICE
    );

    deployTokenCollateral(
      CollateralParams({
        name: TKN,
        liquidationPenalty: TKN_LIQUIDATION_PENALTY,
        liquidationQuantity: TKN_LIQUIDATION_QUANTITY,
        debtCeiling: TKN_DEBT_CEILING,
        safetyCRatio: TKN_SAFETY_C_RATIO,
        liquidationRatio: TKN_LIQUIDATION_RATIO,
        stabilityFee: TKN_STABILITY_FEE
      }),
      TEST_TKN_PRICE
    );
  }

  function deployETHCollateral(CollateralParams memory _params, uint256 _initialPrice) public {
    vm.startBroadcast(_deployerPk);

    // deploy oracle for test
    oracle[ETH_A] = new OracleForTest(_initialPrice);

    // deploy ETHJoin and CollateralAuctionHouse
    ethJoin = new ETHJoin(address(safeEngine), ETH_A);
    collateralAuctionHouse[ETH_A] = new CollateralAuctionHouse({
        _safeEngine: address(safeEngine), 
        _liquidationEngine: address(liquidationEngine), 
        _collateralType: ETH_A
        });

    _setupCollateral(_params, address(oracle[ETH_A]));

    vm.stopBroadcast();
  }

  function deployTokenCollateral(CollateralParams memory _params, uint256 _initialPrice) public {
    vm.startBroadcast(_deployerPk);

    // deploy oracle for test
    oracle[_params.name] = new OracleForTest(_initialPrice);

    // deploy Collateral, CollateralJoin and CollateralAuctionHouse
    collateral[_params.name] = new ERC20ForTest(); // TODO: replace for token
    collateralJoin[_params.name] = new CollateralJoin({
        _safeEngine: address(safeEngine), 
        _collateralType: _params.name, 
        _collateral: address(collateral[_params.name])
        });
    collateralAuctionHouse[_params.name] = new CollateralAuctionHouse({
        _safeEngine: address(safeEngine), 
        _liquidationEngine: address(liquidationEngine), 
        _collateralType: _params.name
        });

    _setupCollateral(_params, address(oracle[_params.name]));

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
    collateralJoin[TKN].removeAuthorization(deployer);

    // auction houses
    surplusAuctionHouse.removeAuthorization(deployer);
    debtAuctionHouse.removeAuthorization(deployer);

    // collateral auction houses
    collateralAuctionHouse[ETH_A].removeAuthorization(deployer);
    collateralAuctionHouse[TKN].removeAuthorization(deployer);

    vm.stopBroadcast();
  }

  function deployAndSetup(GlobalParams memory _params) public {
    vm.startBroadcast(_deployerPk);

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
    debtAuctionHouse.modifyParameters('accountingEngine', address(accountingEngine));
    taxCollector.modifyParameters('primaryTaxReceiver', address(accountingEngine));
    liquidationEngine.modifyParameters('accountingEngine', address(accountingEngine));
    accountingEngine.modifyParameters('protocolTokenAuthority', address(protocolToken));

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
    globalSettlement.modifyParameters('safeEngine', address(safeEngine));
    safeEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('liquidationEngine', address(liquidationEngine));
    liquidationEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('stabilityFeeTreasury', address(stabilityFeeTreasury));
    stabilityFeeTreasury.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('accountingEngine', address(accountingEngine));
    accountingEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('oracleRelayer', address(oracleRelayer));
    oracleRelayer.addAuthorization(address(globalSettlement));
    // globalSettlement.modifyParameters('coinSavingsAccount', address(oracleRelayer));
    // coinSavingsAccount.addAuthorization(address(globalSettlement));

    // setup params
    safeEngine.modifyParameters('globalDebtCeiling', _params.globalDebtCeiling);
    taxCollector.modifyParameters('globalStabilityFee', _params.globalStabilityFee);
    accountingEngine.modifyParameters('initialDebtAuctionMintedTokens', _params.initialDebtAuctionMintedTokens);
    accountingEngine.modifyParameters('debtAuctionBidSize', _params.bidAuctionSize);
    accountingEngine.modifyParameters('surplusAuctionAmountToSell', _params.surplusAuctionAmountToSell);
    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', _params.surplusAuctionBidReceiver);

    vm.stopBroadcast();
  }

  function _setupCollateral(CollateralParams memory _params, address _collateralOracle) internal {
    address _collateralJoin = _params.name == ETH_A ? address(ethJoin) : address(collateralJoin[_params.name]);
    safeEngine.addAuthorization(_collateralJoin);

    oracleRelayer.modifyParameters(_params.name, 'orcl', _collateralOracle);

    safeEngine.initializeCollateralType(_params.name);
    taxCollector.initializeCollateralType(_params.name);

    collateralAuctionHouse[_params.name].addAuthorization(address(liquidationEngine));
    liquidationEngine.addAuthorization(address(collateralAuctionHouse[_params.name]));
    // collateralAuctionHouse[_params.name].addAuthorization(address(globalSettlement));
    // TODO: change for a FSM oracle

    // setup registry
    collateralAuctionHouse[_params.name].modifyParameters('oracleRelayer', address(oracleRelayer));
    collateralAuctionHouse[_params.name].modifyParameters('collateralFSM', address(_collateralOracle));
    liquidationEngine.modifyParameters(
      _params.name, 'collateralAuctionHouse', address(collateralAuctionHouse[_params.name])
    );
    liquidationEngine.modifyParameters(_params.name, 'liquidationPenalty', _params.liquidationPenalty);
    liquidationEngine.modifyParameters(_params.name, 'liquidationQuantity', _params.liquidationQuantity);

    // setup params
    safeEngine.modifyParameters(_params.name, 'debtCeiling', _params.debtCeiling);
    taxCollector.modifyParameters(_params.name, 'stabilityFee', _params.stabilityFee);
    oracleRelayer.modifyParameters(_params.name, 'safetyCRatio', _params.safetyCRatio);
    oracleRelayer.modifyParameters(_params.name, 'liquidationCRatio', _params.liquidationRatio);

    // setup global settlement
    collateralAuctionHouse[_params.name].addAuthorization(address(globalSettlement)); // terminateAuctionPrematurely

    // setup initial price
    oracleRelayer.updateCollateralPrice(_params.name);
  }

  function deployPIDController(PIDParams memory _params, uint256 _haiInitialPrice) public {
    vm.startBroadcast(_deployerPk);
    oracle[HAI] = new OracleForTest(_haiInitialPrice);

    pidController = new PIDController({
      _Kp: _params.proportionalGain,
      _Ki: _params.integralGain,
      _perSecondCumulativeLeak: _params.perSecondCumulativeLeak,
      _integralPeriodSize: _params.periodSize, // TODO: rename ips to ps
      _noiseBarrier: _params.noiseBarrier,
      _feedbackOutputUpperBound: _params.feedbackOutputUpperBound,
      _feedbackOutputLowerBound: _params.feedbackOutputLowerBound,
      _importedState: new int256[](0)
    });

    pidRateSetter = new PIDRateSetter({
     _oracleRelayer: address(oracleRelayer),
     _orcl: address(oracle[HAI]),
     _pidCalculator: address(pidController),
     _updateRateDelay: _params.updateRate
    });

    // setup registry
    pidController.modifyParameters('seedProposer', address(pidRateSetter));

    // auth
    oracleRelayer.addAuthorization(address(pidRateSetter));

    // initialize
    pidRateSetter.updateRate();

    vm.stopBroadcast();
  }
}

contract DeployMainnet is Deploy {
  constructor() {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
    chainId = 10;
  }
}

contract DeployGoerli is Deploy {
  constructor() {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    chainId = 420;
  }
}
