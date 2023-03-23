pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import 'ds-test/test.sol';
import {DSToken as DSDelegateToken} from '../../contracts/for-test/DSToken.sol';

import {SAFEEngine} from '../../contracts/SAFEEngine.sol';
import {LiquidationEngine} from '../../contracts/LiquidationEngine.sol';
import {AccountingEngine} from '../../contracts/AccountingEngine.sol';
import {TaxCollector} from '../../contracts/TaxCollector.sol';
import {CoinJoin} from '../../contracts/utils/CoinJoin.sol';
import {ETHJoin} from '../../contracts/utils/ETHJoin.sol';
import {CollateralJoin} from '../../contracts/utils/CollateralJoin.sol';
import {OracleRelayer} from '../../contracts/OracleRelayer.sol';

import {EnglishCollateralAuctionHouse} from './CollateralAuctionHouse.t.sol';
import {DebtAuctionHouse} from './DebtAuctionHouse.t.sol';
import {PostSettlementSurplusAuctionHouse} from './SurplusAuctionHouse.t.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
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

contract TestSAFEEngine is SAFEEngine {
  constructor() {}

  function mint(address usr, uint256 wad) public {
    coinBalance[usr] += wad * RAY;
    globalDebt += wad * RAY;
  }

  function balanceOf(address usr) public view returns (uint256) {
    return uint256(coinBalance[usr] / RAY);
  }
}

contract TestAccountingEngine is AccountingEngine {
  constructor(
    address safeEngine,
    address surplusAuctionHouse,
    address debtAuctionHouse
  ) AccountingEngine(safeEngine, surplusAuctionHouse, debtAuctionHouse) {}

  function totalDeficit() public view returns (uint256) {
    return safeEngine.debtBalance(address(this));
  }

  function totalSurplus() public view returns (uint256) {
    return safeEngine.coinBalance(address(this));
  }

  function preAuctionDebt() public view returns (uint256) {
    return subtract(subtract(totalDeficit(), totalQueuedDebt), totalOnAuctionDebt);
  }
}

// --- Saviours ---
contract RevertableSaviour {
  address liquidationEngine;

  constructor(address liquidationEngine_) {
    liquidationEngine = liquidationEngine_;
  }

  function saveSAFE(address liquidator, bytes32, address) public returns (bool, uint256, uint256) {
    if (liquidator == liquidationEngine) {
      return (true, uint256(int256(-1)), uint256(int256(-1)));
    } else {
      revert();
    }
  }
}

contract MissingFunctionSaviour {
  function random() public returns (bool, uint256, uint256) {
    return (true, 1, 1);
  }
}

contract FaultyReturnableSaviour {
  function saveSAFE(address, bytes32, address) public returns (bool, uint256) {
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

  TestSAFEEngine safeEngine;
  TestAccountingEngine accountingEngine;
  LiquidationEngine liquidationEngine;
  DSDelegateToken gold;
  TaxCollector taxCollector;

  CollateralJoin collateralA;

  EnglishCollateralAuctionHouse collateralAuctionHouse;
  DebtAuctionHouse debtAuctionHouse;
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;

  DSDelegateToken protocolToken;

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

  function tokenCollateral(bytes32 collateralType, address safe) internal view returns (uint256) {
    return safeEngine.tokenCollateral(collateralType, safe);
  }

  function lockedCollateral(bytes32 collateralType, address safe) internal view returns (uint256) {
    (uint256 lockedCollateral_, uint256 generatedDebt_) = safeEngine.safes(collateralType, safe);
    generatedDebt_;
    return lockedCollateral_;
  }

  function generatedDebt(bytes32 collateralType, address safe) internal view returns (uint256) {
    (uint256 lockedCollateral_, uint256 generatedDebt_) = safeEngine.safes(collateralType, safe);
    lockedCollateral_;
    return generatedDebt_;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    protocolToken = new DSDelegateToken('GOV', 'GOV');
    protocolToken.mint(100 ether);

    safeEngine = new TestSAFEEngine();
    safeEngine = safeEngine;

    surplusAuctionHouse = new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken));
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken));

    accountingEngine = new TestAccountingEngine(
          address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse)
        );
    surplusAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.modifyParameters('accountingEngine', address(accountingEngine));
    safeEngine.addAuthorization(address(accountingEngine));

    taxCollector = new TaxCollector(address(safeEngine));
    taxCollector.initializeCollateralType('gold');
    taxCollector.modifyParameters('primaryTaxReceiver', address(accountingEngine));
    safeEngine.addAuthorization(address(taxCollector));

    liquidationEngine = new LiquidationEngine(address(safeEngine));
    liquidationEngine.modifyParameters('accountingEngine', address(accountingEngine));
    safeEngine.addAuthorization(address(liquidationEngine));
    accountingEngine.addAuthorization(address(liquidationEngine));

    gold = new DSDelegateToken('GEM', 'GEM');
    gold.mint(1000 ether);

    safeEngine.initializeCollateralType('gold');
    collateralA = new CollateralJoin(address(safeEngine), 'gold', address(gold));
    safeEngine.addAuthorization(address(collateralA));
    gold.approve(address(collateralA));
    collateralA.join(address(this), 1000 ether);

    safeEngine.modifyParameters('gold', 'safetyPrice', ray(1 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', rad(1000 ether));
    safeEngine.modifyParameters('globalDebtCeiling', rad(1000 ether));

    collateralAuctionHouse = new EnglishCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), 'gold');
    collateralAuctionHouse.addAuthorization(address(liquidationEngine));

    liquidationEngine.addAuthorization(address(collateralAuctionHouse));
    liquidationEngine.modifyParameters('gold', 'collateralAuctionHouse', address(collateralAuctionHouse));
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', 1 ether);

    safeEngine.addAuthorization(address(collateralAuctionHouse));
    safeEngine.addAuthorization(address(surplusAuctionHouse));
    safeEngine.addAuthorization(address(debtAuctionHouse));

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    gold.approve(address(safeEngine));
    protocolToken.approve(address(surplusAuctionHouse));

    me = address(this);
  }

  function liquidateSAFE() internal {
    uint256 MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / 10 ** 27;
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', MAX_LIQUIDATION_QUANTITY);
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', 1.1 ether);

    safeEngine.modifyParameters('globalDebtCeiling', rad(300_000 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', rad(300_000 ether));
    safeEngine.modifyParameters('gold', 'safetyPrice', ray(5 ether));
    safeEngine.modifyParameters('gold', 'liquidationPrice', ray(5 ether));
    safeEngine.modifySAFECollateralization('gold', me, me, me, 10 ether, 50 ether);

    safeEngine.modifyParameters('gold', 'safetyPrice', ray(2 ether)); // now unsafe
    safeEngine.modifyParameters('gold', 'liquidationPrice', ray(2 ether));

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(auction, 1);
  }

  function liquidateSavedSAFE() internal {
    uint256 MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / 10 ** 27;
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', MAX_LIQUIDATION_QUANTITY);
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', 1.1 ether);

    safeEngine.modifyParameters('globalDebtCeiling', rad(300_000 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', rad(300_000 ether));
    safeEngine.modifyParameters('gold', 'safetyPrice', ray(5 ether));
    safeEngine.modifyParameters('gold', 'liquidationPrice', ray(5 ether));
    safeEngine.modifySAFECollateralization('gold', me, me, me, 10 ether, 50 ether);

    safeEngine.modifyParameters('gold', 'safetyPrice', ray(2 ether)); // now unsafe
    safeEngine.modifyParameters('gold', 'liquidationPrice', ray(2 ether));

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(auction, 0);
  }

  function test_revertable_saviour() public {
    RevertableSaviour saviour = new RevertableSaviour(address(liquidationEngine));
    liquidationEngine.connectSAFESaviour(address(saviour));
    liquidationEngine.protectSAFE('gold', me, address(saviour));
    assertTrue(liquidationEngine.chosenSAFESaviour('gold', me) == address(saviour));
    liquidateSAFE();
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
    liquidateSAFE();
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

    liquidateSavedSAFE();

    (uint256 lockedCollateral,) = safeEngine.safes('gold', me);
    assertEq(lockedCollateral, 10_910 ether);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
  }
}
