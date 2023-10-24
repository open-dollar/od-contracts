// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';
import {CoinForTest} from '@test/mocks/CoinForTest.sol';

import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {ILiquidationEngine, LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {IAccountingEngine, AccountingEngine} from '@contracts/AccountingEngine.sol';
import {ITaxCollector, TaxCollector} from '@contracts/TaxCollector.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {
  ICollateralJoinFactory,
  ICollateralJoin,
  CollateralJoinFactory
} from '@contracts/factories/CollateralJoinFactory.sol';
import {IOracleRelayer, OracleRelayer} from '@contracts/OracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

import {DelayedOracleForTest} from '@test/mocks/DelayedOracleForTest.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {RAY, WAD} from '@libraries/Math.sol';

import {ICollateralAuctionHouse, CollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {IDebtAuctionHouse, DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {
  IPostSettlementSurplusAuctionHouse,
  PostSettlementSurplusAuctionHouse
} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
  function store(address, bytes32, bytes32) external virtual;
  function prank(address) external virtual;
}

contract Usr {
  SAFEEngine public safeEngine;

  constructor(SAFEEngine _safeEngine) {
    safeEngine = _safeEngine;
  }

  function try_call(address addr, bytes calldata data) external returns (bool) {
    bytes memory _data = data;
    assembly {
      let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
      let free := mload(0x40)
      mstore(free, ok)
      mstore(0x40, add(free, 32))
      revert(free, 32)
    }
  }

  function can_modifySAFECollateralization(
    bytes32 _collateralType,
    address safe,
    address collateralSource,
    address debtDestination,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public returns (bool) {
    string memory _sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    bytes memory _data = abi.encodeWithSignature(
      _sig, _collateralType, safe, collateralSource, debtDestination, deltaCollateral, deltaDebt
    );

    bytes memory _can_call = abi.encodeWithSignature('try_call(address,bytes)', safeEngine, _data);
    (bool _ok, bytes memory _success) = address(this).call(_can_call);

    _ok = abi.decode(_success, (bool));
    if (_ok) return true;
  }

  function can_transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address src,
    address dst,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public returns (bool) {
    string memory _sig = 'transferSAFECollateralAndDebt(bytes32,address,address,int256,int256)';
    bytes memory data = abi.encodeWithSignature(_sig, _collateralType, src, dst, deltaCollateral, deltaDebt);

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', safeEngine, data);
    (bool ok, bytes memory success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
    if (ok) return true;
  }

  function approve(address _token, address _target, uint256 _wad) external {
    CoinForTest(_token).approve(_target, _wad);
  }

  function join(address _adapter, address _safe, uint256 _wad) external {
    ICollateralJoin(_adapter).join(_safe, _wad);
  }

  function exit(address _adapter, address _safe, uint256 _wad) external {
    ICollateralJoin(_adapter).exit(_safe, _wad);
  }

  function modifySAFECollateralization(
    bytes32 _collateralType,
    address _safe,
    address _collateralSrc,
    address _debtDst,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) public {
    safeEngine.modifySAFECollateralization(
      _collateralType, _safe, _collateralSrc, _debtDst, _deltaCollateral, _deltaDebt
    );
  }

  function transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _src,
    address _dst,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) public {
    safeEngine.transferSAFECollateralAndDebt(_collateralType, _src, _dst, _deltaCollateral, _deltaDebt);
  }

  function approveSAFEModification(address _usr) public {
    safeEngine.approveSAFEModification(_usr);
  }
}

contract SingleModifySAFECollateralizationTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  CoinForTest gold;
  CoinForTest stable;
  TaxCollector taxCollector;

  ICollateralJoinFactory collateralJoinFactory;
  ICollateralJoin collateralA;
  address me;

  function try_modifySAFECollateralization(
    bytes32 _collateralType,
    int256 _collateralToDeposit,
    int256 _generatedDebt
  ) public returns (bool _ok) {
    string memory _sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    address _self = address(this);
    (_ok,) = address(safeEngine).call(
      abi.encodeWithSignature(_sig, _collateralType, _self, _self, _self, _collateralToDeposit, _generatedDebt)
    );
  }

  function try_transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _dst,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) public returns (bool _ok) {
    string memory _sig = 'transferSAFECollateralAndDebt(bytes32,address,address,int256,int256)';
    address _self = address(this);
    (_ok,) = address(safeEngine).call(
      abi.encodeWithSignature(_sig, _collateralType, _self, _dst, _deltaCollateral, _deltaDebt)
    );
  }

  function ray(uint256 _wad) internal pure returns (uint256) {
    return _wad * 10 ** 9;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: rad(1000 ether)});
    safeEngine = new SAFEEngine(_safeEngineParams);

    gold = new CoinForTest('GEM', '');
    gold.mint(1000 ether);

    ISAFEEngine.SAFEEngineCollateralParams memory _collateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: rad(1000 ether), debtFloor: 0});
    safeEngine.initializeCollateralType('gold', abi.encode(_collateralParams));

    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
    safeEngine.addAuthorization(address(collateralJoinFactory));

    collateralA = collateralJoinFactory.deployCollateralJoin('gold', address(gold));

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    ITaxCollector.TaxCollectorParams memory _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(0x744),
      globalStabilityFee: RAY,
      maxStabilityFeeRange: RAY - 1,
      maxSecondaryReceivers: 0
    });

    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('gold', abi.encode(_taxCollectorCollateralParams));
    safeEngine.addAuthorization(address(taxCollector));

    gold.approve(address(collateralA), type(uint256).max);
    collateralA.join(address(this), 1000 ether);

    me = address(this);
  }

  function test_setup() public {
    assertEq(gold.balanceOf(address(collateralA)), 1000 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
  }

  function test_join() public {
    address safe = address(this);
    gold.mint(500 ether);
    assertEq(gold.balanceOf(address(this)), 500 ether);
    assertEq(gold.balanceOf(address(collateralA)), 1000 ether);
    collateralA.join(safe, 500 ether);
    assertEq(gold.balanceOf(address(this)), 0 ether);
    assertEq(gold.balanceOf(address(collateralA)), 1500 ether);
    collateralA.exit(safe, 250 ether);
    assertEq(gold.balanceOf(address(this)), 250 ether);
    assertEq(gold.balanceOf(address(collateralA)), 1250 ether);
  }

  function test_lock() public {
    assertEq(safeEngine.safes('gold', address(this)).lockedCollateral, 0 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    safeEngine.modifySAFECollateralization('gold', me, me, me, 6 ether, 0);
    assertEq(safeEngine.safes('gold', address(this)).lockedCollateral, 6 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 994 ether);
    safeEngine.modifySAFECollateralization('gold', me, me, me, -6 ether, 0);
    assertEq(safeEngine.safes('gold', address(this)).lockedCollateral, 0 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
  }

  function test_calm() public {
    // calm means that the debt ceiling is not exceeded
    // it's ok to increase debt as long as you remain calm
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(10 ether)));
    assertTrue(try_modifySAFECollateralization('gold', 10 ether, 9 ether));
    // only if under debt ceiling
    assertTrue(!try_modifySAFECollateralization('gold', 0 ether, 2 ether));
  }

  function test_cool() public {
    // cool means that the debt has decreased
    // it's ok to be over the debt ceiling as long as you're cool
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(10 ether)));
    assertTrue(try_modifySAFECollateralization('gold', 10 ether, 8 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(5 ether)));
    // can decrease debt when over ceiling
    assertTrue(try_modifySAFECollateralization('gold', 0 ether, -1 ether));
  }

  function test_safe() public {
    // safe means that the safe is not risky
    // you can't frob a safe into unsafe
    safeEngine.modifySAFECollateralization('gold', me, me, me, 10 ether, 5 ether); // safe draw
    assertTrue(!try_modifySAFECollateralization('gold', 0 ether, 6 ether)); // unsafe draw
  }

  function test_nice() public {
    // nice means that the collateral has increased or the debt has
    // decreased. remaining unsafe is ok as long as you're nice

    safeEngine.modifySAFECollateralization('gold', me, me, me, 10 ether, 10 ether);
    safeEngine.updateCollateralPrice('gold', ray(0.5 ether), ray(0.5 ether)); // now unsafe

    // debt can't increase if unsafe
    assertTrue(!try_modifySAFECollateralization('gold', 0 ether, 1 ether));
    // debt can decrease
    assertTrue(try_modifySAFECollateralization('gold', 0 ether, -1 ether));
    // lockedCollateral can't decrease
    assertTrue(!try_modifySAFECollateralization('gold', -1 ether, 0 ether));
    // lockedCollateral can increase
    assertTrue(try_modifySAFECollateralization('gold', 1 ether, 0 ether));

    // safe is still unsafe
    // lockedCollateral can't decrease, even if debt decreases more
    assertTrue(!this.try_modifySAFECollateralization('gold', -2 ether, -4 ether));
    // debt can't increase, even if lockedCollateral increases more
    assertTrue(!this.try_modifySAFECollateralization('gold', 5 ether, 1 ether));

    // lockedCollateral can decrease if end state is safe
    assertTrue(this.try_modifySAFECollateralization('gold', -1 ether, -4 ether));
    safeEngine.updateCollateralPrice('gold', ray(0.4 ether), ray(0.4 ether)); // now safe
    // debt can increase if end state is safe
    assertTrue(this.try_modifySAFECollateralization('gold', 5 ether, 1 ether));
  }

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 27;
  }

  function test_alt_callers() public {
    Usr ali = new Usr(safeEngine);
    Usr bob = new Usr(safeEngine);
    Usr che = new Usr(safeEngine);

    address a = address(ali);
    address b = address(bob);
    address c = address(che);

    safeEngine.addAuthorization(a);
    safeEngine.addAuthorization(b);
    safeEngine.addAuthorization(c);

    safeEngine.modifyCollateralBalance('gold', a, int256(rad(20 ether)));
    safeEngine.modifyCollateralBalance('gold', b, int256(rad(20 ether)));
    safeEngine.modifyCollateralBalance('gold', c, int256(rad(20 ether)));

    ali.modifySAFECollateralization('gold', a, a, a, 10 ether, 5 ether);

    // anyone can lock
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, a, 1 ether, 0 ether));
    assertTrue(bob.can_modifySAFECollateralization('gold', a, b, b, 1 ether, 0 ether));
    assertTrue(che.can_modifySAFECollateralization('gold', a, c, c, 1 ether, 0 ether));
    // but only with their own tokenss
    assertTrue(!ali.can_modifySAFECollateralization('gold', a, b, a, 1 ether, 0 ether));
    assertTrue(!bob.can_modifySAFECollateralization('gold', a, c, b, 1 ether, 0 ether));
    assertTrue(!che.can_modifySAFECollateralization('gold', a, a, c, 1 ether, 0 ether));

    // only the lad can frob
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, a, -1 ether, 0 ether));
    assertTrue(!bob.can_modifySAFECollateralization('gold', a, b, b, -1 ether, 0 ether));
    assertTrue(!che.can_modifySAFECollateralization('gold', a, c, c, -1 ether, 0 ether));
    // the lad can frob to anywhere
    assertTrue(ali.can_modifySAFECollateralization('gold', a, b, a, -1 ether, 0 ether));
    assertTrue(ali.can_modifySAFECollateralization('gold', a, c, a, -1 ether, 0 ether));

    // only the lad can draw
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, a, 0 ether, 1 ether));
    assertTrue(!bob.can_modifySAFECollateralization('gold', a, b, b, 0 ether, 1 ether));
    assertTrue(!che.can_modifySAFECollateralization('gold', a, c, c, 0 ether, 1 ether));
    // the lad can draw to anywhere
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, b, 0 ether, 1 ether));
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, c, 0 ether, 1 ether));

    safeEngine.createUnbackedDebt(address(0), address(bob), rad(1 ether));
    safeEngine.createUnbackedDebt(address(0), address(che), rad(1 ether));

    // anyone can wipe
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, a, 0 ether, -1 ether));
    assertTrue(bob.can_modifySAFECollateralization('gold', a, b, b, 0 ether, -1 ether));
    assertTrue(che.can_modifySAFECollateralization('gold', a, c, c, 0 ether, -1 ether));
    // but only with their own coin
    assertTrue(!ali.can_modifySAFECollateralization('gold', a, a, b, 0 ether, -1 ether));
    assertTrue(!bob.can_modifySAFECollateralization('gold', a, b, c, 0 ether, -1 ether));
    assertTrue(!che.can_modifySAFECollateralization('gold', a, c, a, 0 ether, -1 ether));
  }

  function test_approveSAFEModification() public {
    Usr ali = new Usr(safeEngine);
    Usr bob = new Usr(safeEngine);
    Usr che = new Usr(safeEngine);

    address a = address(ali);
    address b = address(bob);
    address c = address(che);

    safeEngine.modifyCollateralBalance('gold', a, int256(rad(20 ether)));
    safeEngine.modifyCollateralBalance('gold', b, int256(rad(20 ether)));
    safeEngine.modifyCollateralBalance('gold', c, int256(rad(20 ether)));

    safeEngine.addAuthorization(a);
    safeEngine.addAuthorization(b);
    safeEngine.addAuthorization(c);

    ali.modifySAFECollateralization('gold', a, a, a, 10 ether, 5 ether);

    // only owner can do risky actions
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, a, 0 ether, 1 ether));
    assertTrue(!bob.can_modifySAFECollateralization('gold', a, b, b, 0 ether, 1 ether));
    assertTrue(!che.can_modifySAFECollateralization('gold', a, c, c, 0 ether, 1 ether));

    ali.approveSAFEModification(address(bob));

    // unless they hope another user
    assertTrue(ali.can_modifySAFECollateralization('gold', a, a, a, 0 ether, 1 ether));
    assertTrue(bob.can_modifySAFECollateralization('gold', a, b, b, 0 ether, 1 ether));
    assertTrue(!che.can_modifySAFECollateralization('gold', a, c, c, 0 ether, 1 ether));
  }

  function test_debtFloor() public {
    assertTrue(try_modifySAFECollateralization('gold', 9 ether, 1 ether));
    safeEngine.modifyParameters('gold', 'debtFloor', abi.encode(rad(5 ether)));
    assertTrue(!try_modifySAFECollateralization('gold', 5 ether, 2 ether));
    assertTrue(try_modifySAFECollateralization('gold', 0 ether, 5 ether));
    assertTrue(!try_modifySAFECollateralization('gold', 0 ether, -5 ether));
    assertTrue(try_modifySAFECollateralization('gold', 0 ether, -6 ether));
  }
}

contract SingleSAFEDebtLimitTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  CoinForTest gold;
  CoinForTest stable;
  TaxCollector taxCollector;

  ICollateralJoinFactory collateralJoinFactory;
  ICollateralJoin collateralA;
  address me;

  function try_modifySAFECollateralization(
    bytes32 _collateralType,
    int256 _collateralToDeposit,
    int256 _generatedDebt
  ) public returns (bool ok) {
    string memory _sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    address _self = address(this);
    (ok,) = address(safeEngine).call(
      abi.encodeWithSignature(_sig, _collateralType, _self, _self, _self, _collateralToDeposit, _generatedDebt)
    );
  }

  function try_transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address dst,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public returns (bool ok) {
    string memory _sig = 'transferSAFECollateralAndDebt(bytes32,address,address,int256,int256)';
    address _self = address(this);
    (ok,) =
      address(safeEngine).call(abi.encodeWithSignature(_sig, _collateralType, _self, dst, deltaCollateral, deltaDebt));
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

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: rad(1000 ether)});
    safeEngine = new SAFEEngine(_safeEngineParams);

    gold = new CoinForTest('GEM', '');
    gold.mint(1000 ether);

    ISAFEEngine.SAFEEngineCollateralParams memory _collateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: rad(1000 ether), debtFloor: 0});
    safeEngine.initializeCollateralType('gold', abi.encode(_collateralParams));

    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
    safeEngine.addAuthorization(address(collateralJoinFactory));
    collateralA = collateralJoinFactory.deployCollateralJoin('gold', address(gold));

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    ITaxCollector.TaxCollectorParams memory _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(0x1234),
      globalStabilityFee: RAY,
      maxStabilityFeeRange: RAY - 1,
      maxSecondaryReceivers: 0
    });

    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('gold', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('gold', 'stabilityFee', abi.encode(1_000_000_564_701_133_626_865_910_626)); // 5% / day
    safeEngine.addAuthorization(address(taxCollector));

    gold.approve(address(collateralA), type(uint256).max);

    safeEngine.addAuthorization(address(safeEngine));

    collateralA.join(address(this), 1000 ether);

    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(10 ether)));
    safeEngine.modifyParameters('safeDebtCeiling', abi.encode(5 ether));

    me = address(this);
  }

  function test_setup() public {
    assertEq(gold.balanceOf(address(collateralA)), 1000 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    uint256 _safeDebtCeiling = safeEngine.params().safeDebtCeiling;
    assertEq(_safeDebtCeiling, 5 ether);
  }

  function testFail_generate_debt_above_safe_limit() public {
    Usr ali = new Usr(safeEngine);
    address a = address(ali);

    safeEngine.addAuthorization(a);
    safeEngine.modifyCollateralBalance('gold', a, int256(rad(20 ether)));

    ali.modifySAFECollateralization('gold', a, a, a, 10 ether, 7 ether);
  }

  function testFail_generate_debt_above_collateral_ceiling_but_below_safe_limit() public {
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(4 ether)));
    assertTrue(try_modifySAFECollateralization('gold', 10 ether, 4.5 ether));
  }

  function test_repay_debt() public {
    Usr ali = new Usr(safeEngine);
    address a = address(ali);

    safeEngine.addAuthorization(a);
    safeEngine.modifyCollateralBalance('gold', a, int256(rad(20 ether)));

    ali.modifySAFECollateralization('gold', a, a, a, 10 ether, 5 ether);
    ali.modifySAFECollateralization('gold', a, a, a, 0, -5 ether);
  }

  function test_tax_and_repay_debt() public {
    Usr ali = new Usr(safeEngine);
    address a = address(ali);

    safeEngine.addAuthorization(a);
    safeEngine.modifyCollateralBalance('gold', a, int256(rad(20 ether)));

    ali.modifySAFECollateralization('gold', a, a, a, 10 ether, 5 ether);

    hevm.warp(block.timestamp + 1 days);
    taxCollector.taxSingle('gold');

    ali.modifySAFECollateralization('gold', a, a, a, 0, -4 ether);
  }

  function test_change_safe_limit_and_modify_cratio() public {
    Usr ali = new Usr(safeEngine);
    address a = address(ali);

    safeEngine.addAuthorization(a);
    safeEngine.modifyCollateralBalance('gold', a, int256(rad(20 ether)));

    ali.modifySAFECollateralization('gold', a, a, a, 10 ether, 5 ether);

    safeEngine.modifyParameters('safeDebtCeiling', abi.encode(4 ether));

    assertTrue(!try_modifySAFECollateralization('gold', 0, 2 ether));
    ali.modifySAFECollateralization('gold', a, a, a, 0, -1 ether);
    assertTrue(!try_modifySAFECollateralization('gold', 0, 2 ether));

    safeEngine.modifyParameters('safeDebtCeiling', abi.encode(uint256(int256(-1))));
    ali.modifySAFECollateralization('gold', a, a, a, 0, 4 ether);
  }
}

contract SingleJoinTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  CoinForTest collateral;
  ICollateralJoinFactory collateralJoinFactory;
  ICollateralJoin collateralA;
  CoinJoin coinA;
  CoinForTest coin;
  address me;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('ETH', abi.encode(_safeEngineCollateralParams));

    collateral = new CoinForTest('Coin', 'Coin');
    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
    safeEngine.addAuthorization(address(collateralJoinFactory));
    collateralA = collateralJoinFactory.deployCollateralJoin('collateral', address(collateral));

    coin = new CoinForTest('Coin', 'Coin');
    coinA = new CoinJoin(address(safeEngine), address(coin));
    safeEngine.addAuthorization(address(coinA));
    coin.addAuthorization(address(coinA));

    me = address(this);
  }

  function try_disable_contract(address a) public returns (bool ok) {
    string memory _sig = 'disableContract()';
    (ok,) = a.call(abi.encodeWithSignature(_sig));
  }

  function try_disable_collateralJoin(bytes32 _cType) public returns (bool ok) {
    string memory _sig = 'disableCollateralJoin(bytes32)';
    (ok,) = address(collateralJoinFactory).call(abi.encodeWithSignature(_sig, _cType));
  }

  function try_join_tokenCollateral(address usr, uint256 wad) public returns (bool ok) {
    string memory _sig = 'join(address,uint256)';
    (ok,) = address(collateralA).call(abi.encodeWithSignature(_sig, usr, wad));
  }

  function try_exit_coin(address usr, uint256 wad) public returns (bool ok) {
    string memory _sig = 'exit(address,uint256)';
    (ok,) = address(coinA).call(abi.encodeWithSignature(_sig, usr, wad));
  }

  receive() external payable {}

  function test_collateral_join() public {
    collateral.mint(20 ether);
    collateral.approve(address(collateralA), 20 ether);
    assertTrue(try_join_tokenCollateral(address(this), 10 ether));
    assertEq(safeEngine.tokenCollateral('collateral', me), 10 ether);
    assertTrue(try_disable_collateralJoin(bytes32('collateral')));
    assertTrue(!try_join_tokenCollateral(address(this), 10 ether));
    assertEq(safeEngine.tokenCollateral('collateral', me), 10 ether);
  }

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 27;
  }

  function test_coin_exit() public {
    address safe = address(this);
    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    safeEngine.approveSAFEModification(address(coinA));
    assertTrue(try_exit_coin(safe, 40 ether));
    assertEq(coin.balanceOf(address(this)), 40 ether);
    assertEq(safeEngine.coinBalance(me), rad(60 ether));
    assertTrue(try_disable_contract(address(coinA)));
    assertTrue(!try_exit_coin(safe, 40 ether));
    assertEq(coin.balanceOf(address(this)), 40 ether);
    assertEq(safeEngine.coinBalance(me), rad(60 ether));
  }

  function test_coin_exit_join() public {
    address safe = address(this);
    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    safeEngine.approveSAFEModification(address(coinA));
    coinA.exit(safe, 60 ether);
    coin.approve(address(coinA), uint256(int256(-1)));
    coinA.join(safe, 30 ether);
    assertEq(coin.balanceOf(address(this)), 30 ether);
    assertEq(safeEngine.coinBalance(me), rad(70 ether));
  }

  function test_disable_contract_no_access() public {
    collateralJoinFactory.removeAuthorization(address(this));
    assertTrue(!try_disable_collateralJoin(bytes32('collateral')));
    coinA.removeAuthorization(address(this));
    assertTrue(!try_disable_contract(address(coinA)));
  }
}

abstract contract EnglishCollateralAuctionHouseLike {
  struct Bid {
    uint256 bidAmount;
    uint256 amountToSell;
    address highBidder;
    uint256 bidExpiry;
    uint256 auctionDeadline;
    address safeAuctioned;
    address auctionIncomeRecipient;
    uint256 amountToRaise;
  }

  function bids(uint256)
    public
    view
    virtual
    returns (
      uint256 bidAmount,
      uint256 amountToSell,
      address highBidder,
      uint256 bidExpiry,
      uint256 auctionDeadline,
      address safeAuctioned,
      address auctionIncomeRecipient,
      uint256 amountToRaise
    );
}

contract SingleLiquidationTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  AccountingEngine accountingEngine;
  LiquidationEngine liquidationEngine;
  CoinForTest gold;
  TaxCollector taxCollector;
  OracleRelayer oracleRelayer;
  DelayedOracleForTest oracleFSM;

  ICollateralJoinFactory collateralJoinFactory;
  ICollateralJoin collateralA;

  CollateralAuctionHouse collateralAuctionHouse;
  DebtAuctionHouse debtAuctionHouse;
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;

  CoinForTest protocolToken;

  address me;

  function try_modifySAFECollateralization(
    bytes32 _collateralType,
    int256 _lockedCollateral,
    int256 _generatedDebt
  ) public returns (bool ok) {
    string memory _sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    address _self = address(this);
    (ok,) = address(safeEngine).call(
      abi.encodeWithSignature(_sig, _collateralType, _self, _self, _self, _lockedCollateral, _generatedDebt)
    );
  }

  function try_liquidate(bytes32 _collateralType, address _safe) public returns (bool ok) {
    string memory _sig = 'liquidateSAFE(bytes32,address)';
    (ok,) = address(liquidationEngine).call(abi.encodeWithSignature(_sig, _collateralType, _safe));
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

    protocolToken = new CoinForTest('GOV', '');
    protocolToken.mint(100 ether);

    OracleForTest mockSystemCoinOracle = new OracleForTest(1 ether);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});

    safeEngine = new SAFEEngine(_safeEngineParams);
    safeEngine = safeEngine;

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

    gold = new CoinForTest('GEM', '');
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
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(1000 ether)));

    IOracleRelayer.OracleRelayerParams memory _oracleRelayerParams =
      IOracleRelayer.OracleRelayerParams({redemptionRateUpperBound: RAY * WAD, redemptionRateLowerBound: 1});
    oracleRelayer = new OracleRelayer({
        _safeEngine: address(safeEngine), 
        _systemCoinOracle: IBaseOracle(address(mockSystemCoinOracle)), 
        _oracleRelayerParams: _oracleRelayerParams
        });
    safeEngine.addAuthorization(address(oracleRelayer));

    oracleFSM = new DelayedOracleForTest(1 ether, address(0));

    oracleRelayer.initializeCollateralType(
      'gold',
      abi.encode(
        IOracleRelayer.OracleRelayerCollateralParams({
          oracle: IDelayedOracle(address(oracleFSM)),
          safetyCRatio: ray(1.5 ether),
          liquidationCRatio: ray(1.5 ether)
        })
      )
    );

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
    protocolToken.addAuthorization(address(debtAuctionHouse));

    me = address(this);
  }

  function test_set_liquidation_quantity() public {
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(115_792 ether)));
    assertEq(liquidationEngine.cParams('gold').liquidationQuantity, rad(115_792 ether));
  }

  function test_set_auction_system_coin_limit() public {
    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(1)));
    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(1));
  }

  function testFail_liquidation_quantity_too_large() public {
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(uint256(int256(-1)) / 10 ** 27 + 1));
  }

  function test_liquidate_max_liquidation_quantity() public {
    uint256 MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / 10 ** 27;
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(MAX_LIQUIDATION_QUANTITY));

    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.updateCollateralPrice('gold', ray(205 ether), ray(205 ether));
    safeEngine.modifySAFECollateralization('gold', me, me, me, 1000 ether, 200_000 ether);

    oracleFSM.setPriceAndValidity(2 ether, true);
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether)); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    CollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(auction);
    assertEq(_auction.amountToRaise, MAX_LIQUIDATION_QUANTITY / 10 ** 27 * 10 ** 27);
  }

  function testFail_liquidate_forced_over_max_liquidation_quantity() public {
    uint256 MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / 10 ** 27;
    hevm.store(
      address(liquidationEngine),
      bytes32(uint256(keccak256(abi.encode(bytes32('gold'), uint256(1)))) + 2),
      bytes32(MAX_LIQUIDATION_QUANTITY + 1)
    );

    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(300_000 ether)));
    safeEngine.updateCollateralPrice('gold', ray(205 ether), ray(205 ether));
    safeEngine.modifySAFECollateralization('gold', me, me, me, 1000 ether, 200_000 ether);

    oracleFSM.setPriceAndValidity(2 ether, true);
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether)); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(auction, 1);
  }

  function test_liquidate_under_liquidation_quantity() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);

    oracleFSM.setPriceAndValidity(2 ether, true);
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether));

    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(111 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', abi.encode(1.1 ether));

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    // the full SAFE is liquidated
    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 0);
    assertEq(_safe.generatedDebt, 0);
    // all debt goes to the accounting engine
    assertEq(accountingEngine.totalQueuedDebt(), rad(100 ether));
    // auction is for all collateral
    CollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(auction);
    assertEq(_auction.amountToSell, 40 ether);
    assertEq(_auction.amountToRaise, rad(110 ether));
  }

  function test_liquidate_over_liquidation_quantity() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);

    oracleFSM.setPriceAndValidity(2 ether, true);
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether));

    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(82.5 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', abi.encode(1.1 ether));

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    // the SAFE is partially liquidated
    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 10 ether);
    assertEq(_safe.generatedDebt, 25 ether);
    // all debt goes to the accounting engine
    assertEq(accountingEngine.totalQueuedDebt(), rad(75 ether));
    // auction is for all collateral
    CollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(auction);
    assertEq(_auction.amountToSell, 30 ether);
    assertEq(_auction.amountToRaise, rad(82.5 ether));
  }

  function test_liquidate_happy_safe() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether)); // $2.5
    oracleFSM.setPriceAndValidity(2.5 ether, true); // auction uses this price feed
    uint256 _auctionDiscount = 0.95e18; // 5% discount

    // safety: 40 collateral tokens => $100
    // debt:   100 system coins => $100
    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);
    // updates collateral price to make it liquidatable (== 1.25 liquidationCRatio)
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether));

    uint256 _initialCollatBalance = safeEngine.tokenCollateral('gold', address(this));

    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 40 ether);
    assertEq(_safe.generatedDebt, 100 ether);
    assertEq(accountingEngine.totalQueuedDebt(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 960 ether);

    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(200 ether))); // => liquidate everything
    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 0);
    assertEq(_safe.generatedDebt, 0);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(100 ether)); // 100 system coins

    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0 ether);
    collateralAuctionHouse.buyCollateral(auction, 40 ether); // debt -= 40 => 60
    // collateral bought for 40 system coins: 40 / (2.5 * 0.95) = 16.84
    assertEq(safeEngine.tokenCollateral('gold', address(this)), _initialCollatBalance + 16_842_105_263_157_894_736);
    collateralAuctionHouse.buyCollateral(auction, 40 ether); // debt -= 40 => 20
    assertEq(safeEngine.tokenCollateral('gold', address(this)), _initialCollatBalance + 2 * 16_842_105_263_157_894_736);

    assertEq(safeEngine.coinBalance(address(this)), rad(20 ether)); // 20 coins left

    // magic up some 100 system coins for bidding more
    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));

    /**
     * NOTE:
     * - there's a remaining debt of 20 coins (40 ether is overbidding)
     * - there was initially 40 collateral tokens, and 33.6 were sold
     * - remaining amount of collateral tokens is 6.4
     */
    collateralAuctionHouse.buyCollateral(auction, 40 ether); // buy all left
    assertEq(_initialCollatBalance + 2 * 16_842_105_263_157_894_736 + 6_315_789_473_684_210_528, 1000 ether);

    // NOTE: spent 95 coins to buy all collateral (started 1:1, with 5% discount)
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(95 ether) + ray(5 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(100 ether));

    hevm.warp(block.timestamp + 4 hours);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(95 ether) + ray(5 ether));
  }

  function test_liquidate_when_system_deficit() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);

    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether));

    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(200 ether))); // => liquidate everything
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(0 ether));
    uint256 _auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(100 ether));

    assertEq(accountingEngine.totalQueuedDebt(), rad(100 ether));
    accountingEngine.popDebtFromQueue(block.timestamp);
    assertEq(accountingEngine.totalQueuedDebt(), rad(0 ether));
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), rad(100 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(0 ether));
    assertEq(accountingEngine.totalOnAuctionDebt(), rad(0 ether));

    accountingEngine.modifyParameters('debtAuctionBidSize', abi.encode(rad(10 ether)));
    accountingEngine.modifyParameters('debtAuctionMintedTokens', abi.encode(2000 ether));
    uint256 f1 = accountingEngine.auctionDebt();
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), rad(90 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(0 ether));
    assertEq(accountingEngine.totalOnAuctionDebt(), rad(10 ether));
    debtAuctionHouse.decreaseSoldAmount(f1, 1000 ether);
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), rad(90 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(0 ether));
    assertEq(accountingEngine.totalOnAuctionDebt(), rad(0 ether));

    assertEq(protocolToken.balanceOf(address(this)), 100 ether);
    hevm.warp(block.timestamp + 4 hours);

    debtAuctionHouse.settleAuction(f1);
    assertEq(protocolToken.balanceOf(address(this)), 1100 ether);
  }

  function test_liquidate_when_system_surplus() public {
    protocolToken.approve(address(surplusAuctionHouse), type(uint256).max);

    // get some surplus
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(100 ether));
    assertEq(protocolToken.balanceOf(address(this)), 100 ether);

    accountingEngine.modifyParameters('surplusAmount', abi.encode(rad(100 ether)));
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), 0 ether);
    assertEq(accountingEngine.totalOnAuctionDebt(), 0 ether);
    uint256 id = accountingEngine.auctionSurplus();

    assertEq(safeEngine.coinBalance(address(this)), 0 ether);
    assertEq(protocolToken.balanceOf(address(this)), 100 ether);
    surplusAuctionHouse.increaseBidSize(id, 10 ether);
    hevm.warp(block.timestamp + 4 hours);

    surplusAuctionHouse.settleAuction(id);

    assertEq(safeEngine.coinBalance(address(this)), rad(100 ether));
    assertEq(protocolToken.balanceOf(address(this)), 90 ether);
  }

  // tests a partial liquidation because it would fill the onAuctionSystemCoinLimit
  function test_partial_liquidation_fill_limit() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    uint256 _initialCoins = 150 ether;

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, int256(_initialCoins));

    oracleFSM.setPriceAndValidity(1 ether, true);
    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 100 ether);
    assertEq(_safe.generatedDebt, 150 ether);

    assertEq(accountingEngine.unqueuedUnauctionedDebt(), 0 ether);
    assertEq(accountingEngine.totalOnAuctionDebt(), 0 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 900 ether);

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(75 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(100 ether)));
    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(75 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(75 ether));
    _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 50 ether);
    assertEq(_safe.generatedDebt, 75 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 900 ether);

    assertEq(safeEngine.coinBalance(address(this)), rad(150 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0 ether);
    collateralAuctionHouse.buyCollateral(auction, 5 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(70 ether));
    assertEq(safeEngine.coinBalance(address(this)), rad(145 ether));
    // get's capped at available collateral to sell
    (, uint256 _adjustedBid) = collateralAuctionHouse.getCollateralBought(auction, 70 ether);
    collateralAuctionHouse.buyCollateral(auction, 70 ether); // buys full liquidation
    assertEq(safeEngine.coinBalance(address(this)), rad(145 ether) - rad(_adjustedBid));

    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.coinBalance(address(this)), rad(145 ether) - rad(_adjustedBid));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));

    hevm.warp(block.timestamp + 4 hours);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(safeEngine.coinBalance(address(this)), rad(145 ether) - rad(_adjustedBid));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(5 ether) + rad(_adjustedBid));
  }

  function testFail_liquidate_fill_over_limit() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 100 ether);
    assertEq(_safe.generatedDebt, 150 ether);
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), 0 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 900 ether);

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(75 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(100 ether)));
    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(75 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(75 ether));

    _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 50 ether);
    assertEq(_safe.generatedDebt, 75 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 900 ether);

    liquidationEngine.liquidateSAFE('gold', address(this));
  }

  function test_multiple_liquidations_partial_fill_limit() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);
    uint256 _initialCoinBalance = safeEngine.coinBalance(address(this));

    oracleFSM.setPriceAndValidity(1 ether, true);
    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 100 ether);
    assertEq(_safe.generatedDebt, 150 ether);
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), 0 ether);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 900 ether);

    collateralAuctionHouse.modifyParameters('minimumBid', abi.encode(1 ether));
    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(75 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(100 ether)));
    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(75 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(75 ether));

    _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 50 ether);
    assertEq(_safe.generatedDebt, 75 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 900 ether);

    assertEq(safeEngine.coinBalance(address(this)), rad(150 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0 ether);
    collateralAuctionHouse.buyCollateral(auction, 1 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(74 ether));
    assertEq(safeEngine.coinBalance(address(this)), rad(149 ether));
    // get's capped at available collateral to sell
    (, uint256 _adjustedBid) = collateralAuctionHouse.getCollateralBought(auction, 70 ether);
    uint256 _newCoinBalance = _initialCoinBalance - rad(1 ether) - rad(_adjustedBid);
    collateralAuctionHouse.buyCollateral(auction, 74 ether);
    assertEq(safeEngine.coinBalance(address(this)), _newCoinBalance);

    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));

    // Another liquidateSAFE() here would fail and revert because we would go above the limit so we first
    // have to settle an auction and then liquidate again

    hevm.warp(block.timestamp + 4 hours);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(safeEngine.coinBalance(address(this)), _newCoinBalance);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(1 ether) + rad(_adjustedBid));

    // now liquidate more
    auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(75 ether));

    _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 0);
    assertEq(_safe.generatedDebt, 0);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);

    assertEq(safeEngine.coinBalance(address(this)), _newCoinBalance);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), _initialCoinBalance - _newCoinBalance);
    collateralAuctionHouse.buyCollateral(auction, 1 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(74 ether));
    assertEq(safeEngine.coinBalance(address(this)), _newCoinBalance - rad(1 ether));
    (, _adjustedBid) = collateralAuctionHouse.getCollateralBought(auction, 70 ether);
    _newCoinBalance = _newCoinBalance - rad(1 ether) - rad(_adjustedBid);
    collateralAuctionHouse.buyCollateral(auction, 74 ether);
    assertEq(safeEngine.coinBalance(address(this)), _newCoinBalance);

    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));

    hevm.warp(block.timestamp + 4 hours);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(safeEngine.coinBalance(address(this)), _newCoinBalance);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), _initialCoinBalance - _newCoinBalance);
  }

  function testFail_liquidation_quantity_small_leaves_dust() public {
    safeEngine.modifyParameters('gold', 'debtFloor', abi.encode(rad(150 ether)));
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(150 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(1 ether)));

    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(150 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);

    assertEq(liquidationEngine.getLimitAdjustedDebtToCover('gold', address(this)), 1 ether);

    liquidationEngine.liquidateSAFE('gold', address(this));
  }

  function testFail_liquidation_remaining_on_auction_limit_results_in_dust() public {
    safeEngine.modifyParameters('gold', 'debtFloor', abi.encode(rad(150 ether)));
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(149 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(150 ether)));

    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(149 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);

    assertEq(liquidationEngine.getLimitAdjustedDebtToCover('gold', address(this)), 149 ether);

    liquidationEngine.liquidateSAFE('gold', address(this));
  }

  function test_liquidation_remaining_on_auction_limit_right_above_safe_debt() public {
    safeEngine.modifyParameters('gold', 'debtFloor', abi.encode(rad(149 ether)));
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(150 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(1 ether)));

    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(150 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);

    assertEq(liquidationEngine.getLimitAdjustedDebtToCover('gold', address(this)), 1 ether);

    liquidationEngine.liquidateSAFE('gold', address(this));

    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 99_333_333_333_333_333_334);
    assertEq(_safe.generatedDebt, 149 ether);
  }

  function test_double_liquidate_safe() public {
    safeEngine.modifyParameters('gold', 'debtFloor', abi.encode(rad(149 ether)));
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(rad(150 ether)));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(1 ether)));

    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, rad(150 ether));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);

    assertEq(liquidationEngine.getLimitAdjustedDebtToCover('gold', address(this)), 1 ether);

    liquidationEngine.liquidateSAFE('gold', address(this));

    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(uint256(int256(-1))));
    liquidationEngine.modifyParameters('gold', 'liquidationQuantity', abi.encode(rad(1000 ether)));

    assertEq(liquidationEngine.getLimitAdjustedDebtToCover('gold', address(this)), 149 ether);

    liquidationEngine.liquidateSAFE('gold', address(this));

    ISAFEEngine.SAFE memory _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 0);
    assertEq(_safe.generatedDebt, 0);
  }
}

contract SingleAccumulateRatesTest is DSTest {
  SAFEEngine safeEngine;

  function ray(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 9;
  }

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 27;
  }

  function _totalAdjustedDebt(bytes32 _collateralType, address _safe) internal view returns (uint256) {
    uint256 _generatedDebt = safeEngine.safes(_collateralType, _safe).generatedDebt;
    uint256 accumulatedRate_ = safeEngine.cData(_collateralType).accumulatedRate;
    return _generatedDebt * accumulatedRate_;
  }

  function setUp() public {
    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: rad(100 ether)});

    safeEngine = new SAFEEngine(_safeEngineParams);
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: rad(100 ether), debtFloor: 0});
    safeEngine.initializeCollateralType('gold', abi.encode(_safeEngineCollateralParams));
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(100 ether)));
  }

  function _generateDebt(bytes32 _collateralType, uint256 _coin) internal {
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(_coin)));
    safeEngine.modifyParameters(_collateralType, 'debtCeiling', abi.encode(rad(_coin)));
    uint256 _collateralPrice = 10 ** 27 * 10_000 ether;
    safeEngine.updateCollateralPrice(_collateralType, _collateralPrice, _collateralPrice);
    address _self = address(this);
    safeEngine.modifyCollateralBalance(_collateralType, _self, 10 ** 27 * 1 ether);
    safeEngine.modifySAFECollateralization(_collateralType, _self, _self, _self, 1 ether, int256(_coin));
  }

  function test_accumulate_rates() public {
    address _self = address(this);
    address _ali = address(bytes20('ali'));
    _generateDebt('gold', 1 ether);

    assertEq(_totalAdjustedDebt('gold', _self), rad(1.0 ether));
    safeEngine.updateAccumulatedRate('gold', _ali, int256(ray(0.05 ether)));
    assertEq(_totalAdjustedDebt('gold', _self), rad(1.05 ether));
    assertEq(safeEngine.coinBalance(_ali), rad(0.05 ether));
  }
}
