// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import 'ds-test/test.sol';
import {DSToken as DSDelegateToken} from '@contracts/for-test/DSToken.sol';

import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {ETHJoin} from '@contracts/utils/ETHJoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {OracleRelayer} from '@contracts/OracleRelayer.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {RAY} from '@libraries/Math.sol';

import {IncreasingDiscountCollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {PostSettlementSurplusAuctionHouse} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
  function store(address, bytes32, bytes32) external virtual;
}

contract DummyFSM {
  address public priceSource;
  bool validPrice;
  uint256 price;

  function getResultWithValidity() public view returns (uint256, bool) {
    return (price, validPrice);
  }

  function read() public view returns (uint256) {
    uint256 _price;
    bool _validPrice;
    (_price, _validPrice) = getResultWithValidity();
    require(_validPrice, 'not-valid');
    return uint256(_price);
  }

  function updateCollateralPrice(uint256 _newPrice) public /* note auth */ {
    price = _newPrice;
    validPrice = true;
  }

  function restart() public /* note auth */ {
    // unset the value
    validPrice = false;
  }
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
    DSDelegateToken(_token).approve(_target, _wad);
  }

  function join(address _adapter, address _safe, uint256 _wad) external {
    CollateralJoin(_adapter).join(_safe, _wad);
  }

  function exit(address _adapter, address _safe, uint256 _wad) external {
    CollateralJoin(_adapter).exit(_safe, _wad);
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
  SAFEEngine safeEngine;
  DSDelegateToken gold;
  DSDelegateToken stable;
  TaxCollector taxCollector;

  CollateralJoin collateralA;
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
    safeEngine = new SAFEEngine();

    gold = new DSDelegateToken('GEM', '');
    gold.mint(1000 ether);

    safeEngine.initializeCollateralType('gold');

    collateralA = new CollateralJoin(address(safeEngine), 'gold', address(gold));

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(1000 ether)));
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(1000 ether)));

    taxCollector = new TaxCollector(address(safeEngine));
    taxCollector.initializeCollateralType('gold');
    safeEngine.addAuthorization(address(taxCollector));

    gold.approve(address(collateralA));
    gold.approve(address(safeEngine));

    safeEngine.addAuthorization(address(safeEngine));
    safeEngine.addAuthorization(address(collateralA));

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
  DSDelegateToken gold;
  DSDelegateToken stable;
  TaxCollector taxCollector;

  CollateralJoin collateralA;
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

    safeEngine = new SAFEEngine();

    gold = new DSDelegateToken('GEM', '');
    gold.mint(1000 ether);

    safeEngine.initializeCollateralType('gold');

    collateralA = new CollateralJoin(address(safeEngine), 'gold', address(gold));

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(1000 ether)));
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(1000 ether)));

    taxCollector = new TaxCollector(address(safeEngine));
    taxCollector.initializeCollateralType('gold');
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(0x1234));
    taxCollector.modifyParameters('gold', 'stabilityFee', abi.encode(1_000_000_564_701_133_626_865_910_626)); // 5% / day
    safeEngine.addAuthorization(address(taxCollector));

    gold.approve(address(collateralA));
    gold.approve(address(safeEngine));

    safeEngine.addAuthorization(address(safeEngine));
    safeEngine.addAuthorization(address(collateralA));

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
  SAFEEngine safeEngine;
  DSDelegateToken collateral;
  CollateralJoin collateralA;
  ETHJoin ethA;
  CoinJoin coinA;
  DSDelegateToken coin;
  address me;

  uint256 constant WAD = 10 ** 18;

  function setUp() public {
    safeEngine = new SAFEEngine();
    safeEngine.initializeCollateralType('ETH');

    collateral = new DSDelegateToken('Gem', 'Gem');
    collateralA = new CollateralJoin(address(safeEngine), 'collateral', address(collateral));
    safeEngine.addAuthorization(address(collateralA));

    ethA = new ETHJoin(address(safeEngine), 'ETH');
    safeEngine.addAuthorization(address(ethA));

    coin = new DSDelegateToken('Coin', 'Coin');
    coinA = new CoinJoin(address(safeEngine), address(coin));
    safeEngine.addAuthorization(address(coinA));
    coin.setOwner(address(coinA));

    me = address(this);
  }

  function try_disable_contract(address a) public payable returns (bool ok) {
    string memory _sig = 'disableContract()';
    (ok,) = a.call(abi.encodeWithSignature(_sig));
  }

  function try_join_tokenCollateral(address usr, uint256 wad) public returns (bool ok) {
    string memory _sig = 'join(address,uint256)';
    (ok,) = address(collateralA).call(abi.encodeWithSignature(_sig, usr, wad));
  }

  function try_join_eth(address usr) public payable returns (bool ok) {
    string memory _sig = 'join(address)';
    (ok,) = address(ethA).call{value: msg.value}(abi.encodeWithSignature(_sig, usr));
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
    assertTrue(try_disable_contract(address(collateralA)));
    assertTrue(!try_join_tokenCollateral(address(this), 10 ether));
    assertEq(safeEngine.tokenCollateral('collateral', me), 10 ether);
  }

  function test_eth_join() public {
    assertTrue(this.try_join_eth{value: 10 ether}(address(this)));
    assertEq(safeEngine.tokenCollateral('ETH', me), 10 ether);
    assertTrue(try_disable_contract(address(ethA)));
    assertTrue(!this.try_join_eth{value: 10 ether}(address(this)));
    assertEq(safeEngine.tokenCollateral('ETH', me), 10 ether);
  }

  function test_eth_exit() public {
    address payable _safe = payable(address(this));
    ethA.join{value: 50 ether}(_safe);
    ethA.exit(_safe, 10 ether);
    assertEq(safeEngine.tokenCollateral('ETH', me), 40 ether);
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

  function test_fallback_reverts() public {
    (bool ok,) = address(ethA).call('invalid calldata');
    assertTrue(!ok);
  }

  function test_nonzero_fallback_reverts() public {
    (bool ok,) = address(ethA).call{value: 10}('invalid calldata');
    assertTrue(!ok);
  }

  function test_disable_contract_no_access() public {
    collateralA.removeAuthorization(address(this));
    assertTrue(!try_disable_contract(address(collateralA)));
    ethA.removeAuthorization(address(this));
    assertTrue(!try_disable_contract(address(ethA)));
    coinA.removeAuthorization(address(this));
    assertTrue(!try_disable_contract(address(coinA)));
  }
}

abstract contract EnglishCollateralAuctionHouseLike {
  struct Bid {
    uint256 bidAmount;
    uint256 amountToSell;
    address highBidder;
    uint48 bidExpiry;
    uint48 auctionDeadline;
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
      uint48 bidExpiry,
      uint48 auctionDeadline,
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
  DSDelegateToken gold;
  TaxCollector taxCollector;
  OracleRelayer oracleRelayer;
  DummyFSM oracleFSM;

  CollateralJoin collateralA;

  IncreasingDiscountCollateralAuctionHouse collateralAuctionHouse;
  DebtAuctionHouse debtAuctionHouse;
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;

  DSDelegateToken protocolToken;

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

    protocolToken = new DSDelegateToken('GOV', '');
    protocolToken.mint(100 ether);

    safeEngine = new SAFEEngine();
    safeEngine = safeEngine;

    surplusAuctionHouse = new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken));
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken));

    accountingEngine = new AccountingEngine(
          address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse)
        );
    surplusAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    safeEngine.addAuthorization(address(accountingEngine));

    taxCollector = new TaxCollector(address(safeEngine));
    taxCollector.initializeCollateralType('gold');
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(accountingEngine));
    safeEngine.addAuthorization(address(taxCollector));

    liquidationEngine = new LiquidationEngine(address(safeEngine));
    liquidationEngine.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    safeEngine.addAuthorization(address(liquidationEngine));
    accountingEngine.addAuthorization(address(liquidationEngine));

    gold = new DSDelegateToken('GEM', '');
    gold.mint(1000 ether);

    safeEngine.initializeCollateralType('gold');
    collateralA = new CollateralJoin(address(safeEngine), 'gold', address(gold));
    safeEngine.addAuthorization(address(collateralA));
    gold.approve(address(collateralA));
    collateralA.join(address(this), 1000 ether);

    safeEngine.updateCollateralPrice('gold', ray(1 ether), ray(1 ether));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(1000 ether)));
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(1000 ether)));

    oracleRelayer = new OracleRelayer(address(safeEngine));
    safeEngine.addAuthorization(address(oracleRelayer));

    oracleFSM = new DummyFSM();
    oracleRelayer.modifyParameters('gold', 'oracle', abi.encode(oracleFSM));
    oracleRelayer.modifyParameters('gold', 'safetyCRatio', abi.encode(ray(1.5 ether)));
    oracleRelayer.modifyParameters('gold', 'liquidationCRatio', abi.encode(ray(1.5 ether)));

    collateralAuctionHouse =
      new IncreasingDiscountCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), 'gold');
    collateralAuctionHouse.addAuthorization(address(liquidationEngine));
    collateralAuctionHouse.modifyParameters('oracleRelayer', abi.encode(oracleRelayer));
    collateralAuctionHouse.modifyParameters('collateralFSM', abi.encode(oracleFSM));

    liquidationEngine.addAuthorization(address(collateralAuctionHouse));
    liquidationEngine.modifyParameters('gold', 'collateralAuctionHouse', abi.encode(collateralAuctionHouse));
    liquidationEngine.modifyParameters('gold', 'liquidationPenalty', abi.encode(1 ether));

    safeEngine.addAuthorization(address(collateralAuctionHouse));
    safeEngine.addAuthorization(address(surplusAuctionHouse));
    safeEngine.addAuthorization(address(debtAuctionHouse));

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    gold.approve(address(safeEngine));
    protocolToken.approve(address(surplusAuctionHouse));

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

    oracleFSM.updateCollateralPrice(2 ether);
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether)); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    IncreasingDiscountCollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(auction);
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

    oracleFSM.updateCollateralPrice(2 ether);
    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether)); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(auction, 1);
  }

  function test_liquidate_under_liquidation_quantity() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);

    oracleFSM.updateCollateralPrice(2 ether);
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
    IncreasingDiscountCollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(auction);
    assertEq(_auction.amountToSell, 40 ether);
    assertEq(_auction.amountToRaise, rad(110 ether));
  }

  function test_liquidate_over_liquidation_quantity() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);

    oracleFSM.updateCollateralPrice(2 ether);
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
    IncreasingDiscountCollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(auction);
    assertEq(_auction.amountToSell, 30 ether);
    assertEq(_auction.amountToRaise, rad(82.5 ether));
  }

  function test_liquidate_happy_safe() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));
    oracleFSM.updateCollateralPrice(2.5 ether);

    safeEngine.modifySAFECollateralization('gold', me, me, me, 40 ether, 100 ether);

    safeEngine.updateCollateralPrice('gold', ray(2 ether), ray(2 ether));

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
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(100 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 960 ether);

    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0 ether);
    collateralAuctionHouse.buyCollateral(auction, 40 ether);
    collateralAuctionHouse.buyCollateral(auction, 40 ether);

    assertEq(safeEngine.coinBalance(address(this)), rad(20 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 993_684_210_526_315_789_472);

    // magic up some system coins for bidding
    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    collateralAuctionHouse.buyCollateral(auction, 38 ether);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(100 ether) + ray(1 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(100 ether));

    hevm.warp(block.timestamp + 4 hours);
    collateralAuctionHouse.settleAuction(auction);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(100 ether) + ray(1 ether));
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
    debtAuctionHouse.decreaseSoldAmount(f1, 1000 ether, rad(10 ether));
    assertEq(accountingEngine.unqueuedUnauctionedDebt(), rad(90 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(0 ether));
    assertEq(accountingEngine.totalOnAuctionDebt(), rad(0 ether));

    assertEq(protocolToken.balanceOf(address(this)), 100 ether);
    hevm.warp(block.timestamp + 4 hours);
    protocolToken.setOwner(address(debtAuctionHouse));
    debtAuctionHouse.settleAuction(f1);
    assertEq(protocolToken.balanceOf(address(this)), 1100 ether);
  }

  function test_liquidate_when_system_surplus() public {
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
    surplusAuctionHouse.increaseBidSize(id, rad(100 ether), 10 ether);
    hevm.warp(block.timestamp + 4 hours);
    protocolToken.setOwner(address(surplusAuctionHouse));
    surplusAuctionHouse.settleAuction(id);
    assertEq(safeEngine.coinBalance(address(this)), rad(100 ether));
    assertEq(protocolToken.balanceOf(address(this)), 90 ether);
  }
  // tests a partial liquidation because it would fill the onAuctionSystemCoinLimit

  function test_partial_liquidation_fill_limit() public {
    safeEngine.updateCollateralPrice('gold', ray(2.5 ether), ray(2.5 ether));

    safeEngine.modifySAFECollateralization('gold', me, me, me, 100 ether, 150 ether);

    oracleFSM.updateCollateralPrice(1 ether);
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
    collateralAuctionHouse.buyCollateral(auction, 70 ether); // buys full liquidation
    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));

    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));

    hevm.warp(block.timestamp + 4 hours);
    collateralAuctionHouse.settleAuction(auction); // no effect
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(75 ether));
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

    oracleFSM.updateCollateralPrice(1 ether);
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
    collateralAuctionHouse.buyCollateral(auction, 74 ether);
    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));

    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));

    // Another liquidateSAFE() here would fail and revert because we would go above the limit so we first
    // have to settle an auction and then liquidate again

    hevm.warp(block.timestamp + 4 hours);
    collateralAuctionHouse.settleAuction(auction);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);
    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(75 ether));

    // now liquidate more
    auction = liquidationEngine.liquidateSAFE('gold', address(this));
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(75 ether));

    _safe = safeEngine.safes('gold', address(this));
    assertEq(_safe.lockedCollateral, 0);
    assertEq(_safe.generatedDebt, 0);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 950 ether);

    assertEq(safeEngine.coinBalance(address(this)), rad(75 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(75 ether));
    collateralAuctionHouse.buyCollateral(auction, 1 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(74 ether));
    assertEq(safeEngine.coinBalance(address(this)), rad(74 ether));
    collateralAuctionHouse.buyCollateral(auction, 74 ether);
    assertEq(safeEngine.coinBalance(address(this)), 0);

    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.coinBalance(address(this)), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(accountingEngine.debtQueue(block.timestamp), rad(75 ether));

    hevm.warp(block.timestamp + 4 hours);
    collateralAuctionHouse.settleAuction(auction);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), 0);
    assertEq(safeEngine.tokenCollateral('gold', address(this)), 1000 ether);
    assertEq(safeEngine.coinBalance(address(this)), 0);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(150 ether));
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
    safeEngine = new SAFEEngine();
    safeEngine.initializeCollateralType('gold');
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(100 ether)));
    safeEngine.modifyParameters('gold', 'debtCeiling', abi.encode(rad(100 ether)));
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
