// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';
import {CoinForTest} from '@test/mocks/CoinForTest.sol';

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {ILiquidationEngine, LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {IAccountingEngine, AccountingEngine} from '@contracts/AccountingEngine.sol';
import {ITaxCollector, TaxCollector} from '@contracts/TaxCollector.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {
  ICollateralJoinFactory,
  ICollateralJoin,
  CollateralJoinFactory
} from '@contracts/factories/CollateralJoinFactory.sol';
import {OracleRelayer, IOracleRelayer} from '@contracts/OracleRelayer.sol';
import {IDebtAuctionHouse, DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {ICollateralAuctionHouse, CollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {
  IPostSettlementSurplusAuctionHouse,
  PostSettlementSurplusAuctionHouse
} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {RAY, WAD} from '@libraries/Math.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
  function prank(address) external virtual;
}

contract Feed {
  bytes32 public price;
  bool public validPrice;
  uint256 public lastUpdateTime;

  constructor(uint256 price_, bool validPrice_) {
    price = bytes32(price_);
    validPrice = validPrice_;
    lastUpdateTime = block.timestamp;
  }

  function updateCollateralPrice(uint256 price_) external {
    price = bytes32(price_);
    lastUpdateTime = block.timestamp;
  }

  function getResultWithValidity() external view returns (bytes32, bool) {
    return (price, validPrice);
  }
}

// --- Saviours ---
contract RevertableSaviour {
  address liquidationEngine;

  constructor(address liquidationEngine_) {
    liquidationEngine = liquidationEngine_;
  }

  function saveSAFE(address liquidator, bytes32, address) public view returns (bool, uint256, uint256) {
    if (liquidator == liquidationEngine) {
      return (true, uint256(int256(-1)), uint256(int256(-1)));
    } else {
      revert();
    }
  }
}

contract MissingFunctionSaviour {
  function random() public pure returns (bool, uint256, uint256) {
    return (true, 1, 1);
  }
}

contract FaultyReturnableSaviour {
  function saveSAFE(address, bytes32, address) public pure returns (bool, uint256) {
    return (true, 1);
  }
}

contract ReentrantSaviour {
  address liquidationEngine;

  constructor(address liquidationEngine_) {
    liquidationEngine = liquidationEngine_;
  }

  function saveSAFE(address liquidator, bytes32 collateralType, address safe) public returns (bool, uint256, uint256) {
    if (liquidator == liquidationEngine) {
      return (true, uint256(int256(-1)), uint256(int256(-1)));
    } else {
      LiquidationEngine(msg.sender).liquidateSAFE(collateralType, safe);
      return (true, 1, 1);
    }
  }
}

contract GenuineSaviour {
  address safeEngine;
  address liquidationEngine;

  constructor(address safeEngine_, address liquidationEngine_) {
    safeEngine = safeEngine_;
    liquidationEngine = liquidationEngine_;
  }

  function saveSAFE(address liquidator, bytes32 collateralType, address safe) public returns (bool, uint256, uint256) {
    if (liquidator == liquidationEngine) {
      return (true, uint256(int256(-1)), uint256(int256(-1)));
    } else {
      SAFEEngine(safeEngine).modifySAFECollateralization(collateralType, safe, address(this), safe, 10_900 ether, 0);
      return (true, 10_900 ether, 0);
    }
  }
}

contract SingleSaveSAFETest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  Feed systemCoinFeed;
  OracleRelayer oracleRelayer;
  AccountingEngine accountingEngine;
  LiquidationEngine liquidationEngine;
  CoinForTest gold;
  TaxCollector taxCollector;

  ICollateralJoinFactory collateralJoinFactory;
  ICollateralJoin collateralA;

  CollateralAuctionHouse collateralAuctionHouse;
  DebtAuctionHouse debtAuctionHouse;
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;

  CoinForTest protocolToken;

  address me;

  function try_modifySAFECollateralization(
    bytes32 collateralType,
    int256 lockedCollateral,
    int256 generatedDebt
  ) public returns (bool ok) {
    string memory sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    address self = address(this);
    (ok,) = address(safeEngine).call(
      abi.encodeWithSignature(sig, collateralType, self, self, self, lockedCollateral, generatedDebt)
    );
  }

  function try_liquidate(bytes32 collateralType, address safe) public returns (bool ok) {
    string memory sig = 'liquidateSAFE(bytes32,address)';
    (ok,) = address(liquidationEngine).call(abi.encodeWithSignature(sig, collateralType, safe));
  }

  function ray(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 9;
  }

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 27;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    protocolToken = new CoinForTest('GOV', 'GOV');
    protocolToken.mint(100 ether);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: rad(1000 ether)});
    safeEngine = new SAFEEngine(_safeEngineParams);

    systemCoinFeed = new Feed(1 ether, true);

    IOracleRelayer.OracleRelayerParams memory _oracleRelayerParams =
      IOracleRelayer.OracleRelayerParams({redemptionRateUpperBound: 1e45, redemptionRateLowerBound: 1});
    oracleRelayer =
    new OracleRelayer({_safeEngine: address(safeEngine), _systemCoinOracle: IBaseOracle(address(systemCoinFeed)), _oracleRelayerParams: _oracleRelayerParams});

    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _pssahParams = IPostSettlementSurplusAuctionHouse
      .PostSettlementSAHParams({bidIncrease: 1.05e18, bidDuration: 3 hours, totalAuctionLength: 2 days});
    surplusAuctionHouse =
      new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken), _pssahParams);

    IDebtAuctionHouse.DebtAuctionHouseParams memory _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18,
      amountSoldIncrease: 1.5e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);

    IAccountingEngine.AccountingEngineParams memory _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0,
      surplusDelay: 0,
      popDebtDelay: 0,
      disableCooldown: 0,
      surplusAmount: 0,
      surplusBuffer: 0,
      debtAuctionMintedTokens: 0,
      debtAuctionBidSize: 0
    });

    accountingEngine = new AccountingEngine(
          address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse), _accountingEngineParams
        );
    surplusAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.addAuthorization(address(accountingEngine));
    safeEngine.addAuthorization(address(accountingEngine));

    ITaxCollector.TaxCollectorParams memory _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: RAY,
      maxStabilityFeeRange: RAY - 1,
      maxSecondaryReceivers: 0
    });

    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('gold', abi.encode(_taxCollectorCollateralParams));
    safeEngine.addAuthorization(address(taxCollector));

    ILiquidationEngine.LiquidationEngineParams memory _liquidationEngineParams = ILiquidationEngine
      .LiquidationEngineParams({onAuctionSystemCoinLimit: type(uint256).max, saviourGasLimit: 10_000_000});
    liquidationEngine = new LiquidationEngine(address(safeEngine), address(accountingEngine), _liquidationEngineParams);
    safeEngine.addAuthorization(address(liquidationEngine));
    accountingEngine.addAuthorization(address(liquidationEngine));

    gold = new CoinForTest('GEM', 'GEM');
    gold.mint(1000 ether);

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: rad(1000 ether), debtFloor: 0});
    safeEngine.initializeCollateralType('gold', abi.encode(_safeEngineCollateralParams));
    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
    safeEngine.addAuthorization(address(collateralJoinFactory));
    collateralA = collateralJoinFactory.deployCollateralJoin('gold', address(gold));
    gold.approve(address(collateralA), type(uint256).max);
    collateralA.join(address(this), 1000 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams = ICollateralAuctionHouse
      .CollateralAuctionHouseParams({
      minDiscount: 0.95e18, // 5% discount
      maxDiscount: 0.95e18, // 5% discount
      perSecondDiscountUpdateRate: RAY, // [ray]
      minimumBid: 1e18 // 1 system coin
    });
    collateralAuctionHouse =
    new CollateralAuctionHouse(address(safeEngine), address(liquidationEngine), address(oracleRelayer), 'gold', _cahParams);

    ILiquidationEngine.LiquidationEngineCollateralParams memory _liquidationEngineCollateralParams = ILiquidationEngine
      .LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse),
      liquidationPenalty: 1 ether,
      liquidationQuantity: 0
    });
    liquidationEngine.initializeCollateralType('gold', abi.encode(_liquidationEngineCollateralParams));

    safeEngine.addAuthorization(address(collateralAuctionHouse));
    safeEngine.addAuthorization(address(surplusAuctionHouse));
    safeEngine.addAuthorization(address(debtAuctionHouse));

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    gold.addAuthorization(address(safeEngine));

    protocolToken.approve(address(surplusAuctionHouse), type(uint256).max);

    me = address(this);
  }

  function _liquidateSAFE() internal {
    uint256 MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / 10 ** 27;
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(MAX_LIQUIDATION_QUANTITY));
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', abi.encode(1.1 ether));

    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.updateCollateralPrice('gold', ray(5 ether), ray(5 ether));
    safeEngine.modifySAFECollateralization('gold', me, me, me, 10 ether, 50 ether);

    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether)); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(auction, 1);
  }

  function _liquidateSavedSAFE() internal {
    uint256 MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / 10 ** 27;
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(MAX_LIQUIDATION_QUANTITY));
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', abi.encode(1.1 ether));

    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.updateCollateralPrice('gold', ray(5 ether), ray(5 ether));
    safeEngine.modifySAFECollateralization('gold', me, me, me, 10 ether, 50 ether);

    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether)); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(auction, 0);
  }

  function test_revertable_saviour() public {
    RevertableSaviour saviour = new RevertableSaviour(address(liquidationEngine));
    liquidationEngine.connectSAFESaviour(address(saviour));
    liquidationEngine.protectSAFE('gold', me, address(saviour));
    assertTrue(liquidationEngine.chosenSAFESaviour('gold', me) == address(saviour));
    _liquidateSAFE();
  }

  function testFail_missing_function_saviour() public {
    MissingFunctionSaviour saviour = new MissingFunctionSaviour();
    liquidationEngine.connectSAFESaviour(address(saviour));
  }

  function testFail_faulty_returnable_function_saviour() public {
    FaultyReturnableSaviour saviour = new FaultyReturnableSaviour();
    liquidationEngine.connectSAFESaviour(address(saviour));
  }

  function test_liquidate_reentrant_saviour() public {
    ReentrantSaviour saviour = new ReentrantSaviour(address(liquidationEngine));
    liquidationEngine.connectSAFESaviour(address(saviour));
    liquidationEngine.protectSAFE('gold', me, address(saviour));
    assertTrue(liquidationEngine.chosenSAFESaviour('gold', me) == address(saviour));
    _liquidateSAFE();
  }

  function test_liquidate_genuine_saviour() public {
    GenuineSaviour saviour = new GenuineSaviour(address(safeEngine), address(liquidationEngine));
    liquidationEngine.connectSAFESaviour(address(saviour));
    liquidationEngine.protectSAFE('gold', me, address(saviour));
    safeEngine.approveSAFEModification(address(saviour));
    assertTrue(liquidationEngine.chosenSAFESaviour('gold', me) == address(saviour));

    gold.mint(10_000 ether);
    collateralA.join(address(this), 10_000 ether);
    safeEngine.transferCollateral('gold', me, address(saviour), 10_900 ether);

    _liquidateSavedSAFE();

    uint256 _lockedCollateral = safeEngine.safes('gold', me).lockedCollateral;
    assertEq(_lockedCollateral, 10_910 ether);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
  }
}
