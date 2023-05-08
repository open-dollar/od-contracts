// SPDX-License-Identifier: GPL-3.0
// SingleGlobalSettlement.t.sol

// Copyright (C) 2017  DappHub, LLC
// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018 Lev Livnev <lev@liv.nev.org.uk>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import 'ds-test/test.sol';
import {DSToken as DSDelegateToken} from '@contracts/for-test/DSToken.sol';

import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {IncreasingDiscountCollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {SurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';
import {DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {OracleRelayer} from '@contracts/OracleRelayer.sol';
import {GlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
import {SettlementSurplusAuctioneer} from '@contracts/settlement/SettlementSurplusAuctioneer.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
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

  function updateCollateralPrice(bytes32 _newPrice) public /* note auth */ {
    price = uint256(_newPrice);
    validPrice = true;
  }

  function restart() public /* note auth */ {
    // unset the value
    validPrice = false;
  }
}

contract Usr {
  SAFEEngine public safeEngine;
  GlobalSettlement public globalSettlement;

  constructor(SAFEEngine safeEngine_, GlobalSettlement globalSettlement_) {
    safeEngine = safeEngine_;
    globalSettlement = globalSettlement_;
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

  function transferInternalCoins(address _src, address _dst, uint256 _rad) public {
    safeEngine.transferInternalCoins(_src, _dst, _rad);
  }

  function approveSAFEModification(address usr) public {
    safeEngine.approveSAFEModification(usr);
  }

  function exit(CollateralJoin _collateralA, address _usr, uint256 _wad) public {
    _collateralA.exit(_usr, _wad);
  }

  function freeCollateral(bytes32 _collateralType) public {
    globalSettlement.freeCollateral(_collateralType);
  }

  function prepareCoinsForRedeeming(uint256 _rad) public {
    globalSettlement.prepareCoinsForRedeeming(_rad);
  }

  function redeemCollateral(bytes32 _collateralType, uint256 _wad) public {
    globalSettlement.redeemCollateral(_collateralType, _wad);
  }
}

contract SingleGlobalSettlementTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  GlobalSettlement globalSettlement;
  AccountingEngine accountingEngine;
  LiquidationEngine liquidationEngine;
  OracleRelayer oracleRelayer;
  StabilityFeeTreasury stabilityFeeTreasury;
  SettlementSurplusAuctioneer postSettlementSurplusDrain;

  DSDelegateToken protocolToken;
  DSDelegateToken systemCoin;
  CoinJoin systemCoinA;

  struct CollateralType {
    DummyFSM oracleSecurityModule;
    DSDelegateToken collateral;
    CollateralJoin collateralA;
    IncreasingDiscountCollateralAuctionHouse collateralAuctionHouse;
  }

  mapping(bytes32 => CollateralType) collateralTypes;

  SurplusAuctionHouse surplusAuctionHouseOne;
  DebtAuctionHouse debtAuctionHouse;

  uint256 constant WAD = 10 ** 18;
  uint256 constant RAY = 10 ** 27;

  function ray(uint256 _wad) internal pure returns (uint256) {
    return _wad * 10 ** 9;
  }

  function rad(uint256 _wad) internal pure returns (uint256) {
    return _wad * RAY;
  }

  function rmultiply(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    _z = _x * _y;
    require(_y == 0 || _z / _y == _x);
    _z = _z / RAY;
  }

  function rmultiply(int256 _x, uint256 _y) internal pure returns (int256 _z) {
    _z = _x * int256(_y);
    require(_y == 0 || _z / int256(_y) == _x);
    _z = _z / int256(RAY);
  }

  function minimum(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    (_x >= _y) ? _z = _y : _z = _x;
  }

  function coinBalance(address _safe) internal view returns (uint256) {
    return uint256(safeEngine.coinBalance(_safe) / RAY);
  }

  function tokenCollateral(bytes32 _collateralType, address _safe) internal view returns (uint256) {
    return safeEngine.tokenCollateral(_collateralType, _safe);
  }

  function lockedCollateral(bytes32 _collateralType, address _safe) internal view returns (uint256) {
    (uint256 _lockedCollateral, uint256 _generatedDebt) = safeEngine.safes(_collateralType, _safe);
    _generatedDebt;
    return _lockedCollateral;
  }

  function generatedDebt(bytes32 _collateralType, address _safe) internal view returns (uint256) {
    (uint256 _lockedCollateral, uint256 _generatedDebt) = safeEngine.safes(_collateralType, _safe);
    _lockedCollateral;
    return _generatedDebt;
  }

  function debtAmount(bytes32 collateralType) internal view returns (uint256) {
    (uint256 _debtAmount,) = safeEngine.cData(collateralType);
    return _debtAmount;
  }

  function balanceOf(bytes32 _collateralType, address _usr) internal view returns (uint256) {
    return collateralTypes[_collateralType].collateral.balanceOf(_usr);
  }

  function init_collateral(string memory _name, bytes32 _encodedName) internal returns (CollateralType memory) {
    DSDelegateToken newCollateral = new DSDelegateToken(_name, _name);
    newCollateral.mint(20 ether);

    DummyFSM oracleFSM = new DummyFSM();
    oracleRelayer.modifyParameters(_encodedName, 'orcl', address(oracleFSM));
    oracleRelayer.modifyParameters(_encodedName, 'safetyCRatio', ray(1.5 ether));
    oracleRelayer.modifyParameters(_encodedName, 'liquidationCRatio', ray(1.5 ether));

    // initial collateral price of 5
    oracleFSM.updateCollateralPrice(bytes32(5 * WAD));

    safeEngine.initializeCollateralType(_encodedName);
    CollateralJoin collateralA = new CollateralJoin(address(safeEngine), _encodedName, address(newCollateral));

    safeEngine.modifyParameters(_encodedName, 'safetyPrice', abi.encode(ray(3 ether)));
    safeEngine.modifyParameters(_encodedName, 'liquidationPrice', abi.encode(ray(3 ether)));
    safeEngine.modifyParameters(_encodedName, 'debtCeiling', abi.encode(rad(10_000_000 ether))); // 10M

    newCollateral.approve(address(collateralA));
    newCollateral.approve(address(safeEngine));

    safeEngine.addAuthorization(address(collateralA));

    IncreasingDiscountCollateralAuctionHouse _collateralAuctionHouse =
      new IncreasingDiscountCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), _encodedName);
    safeEngine.approveSAFEModification(address(_collateralAuctionHouse));
    _collateralAuctionHouse.addAuthorization(address(globalSettlement));
    _collateralAuctionHouse.addAuthorization(address(liquidationEngine));
    _collateralAuctionHouse.modifyParameters('oracleRelayer', address(oracleRelayer));
    _collateralAuctionHouse.modifyParameters('collateralFSM', address(oracleFSM));
    oracleFSM.updateCollateralPrice(bytes32(200 * WAD));

    // Start with English auction house
    liquidationEngine.addAuthorization(address(_collateralAuctionHouse));

    liquidationEngine.modifyParameters(_encodedName, 'collateralAuctionHouse', abi.encode(_collateralAuctionHouse));
    liquidationEngine.modifyParameters(_encodedName, 'liquidationPenalty', abi.encode(1 ether));
    liquidationEngine.modifyParameters(
      _encodedName, 'liquidationQuantity', abi.encode(uint256(int256(-1)) / ray(1 ether))
    );

    collateralTypes[_encodedName].oracleSecurityModule = oracleFSM;
    collateralTypes[_encodedName].collateral = newCollateral;
    collateralTypes[_encodedName].collateralA = collateralA;
    collateralTypes[_encodedName].collateralAuctionHouse = _collateralAuctionHouse;

    return collateralTypes[_encodedName];
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    safeEngine = new SAFEEngine();
    protocolToken = new DSDelegateToken('GOV', 'GOV');
    systemCoin = new DSDelegateToken('Coin', 'Coin');
    systemCoinA = new CoinJoin(address(safeEngine), address(systemCoin));

    surplusAuctionHouseOne = new SurplusAuctionHouse(address(safeEngine), address(protocolToken), 0);

    safeEngine.approveSAFEModification(address(surplusAuctionHouseOne));

    protocolToken.approve(address(surplusAuctionHouseOne));

    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken));

    safeEngine.addAuthorization(address(systemCoinA));
    systemCoin.mint(address(this), 50 ether);
    systemCoin.setOwner(address(systemCoinA));

    protocolToken.mint(200 ether);
    protocolToken.setOwner(address(debtAuctionHouse));

    accountingEngine =
      new AccountingEngine(address(safeEngine), address(surplusAuctionHouseOne), address(debtAuctionHouse));
    postSettlementSurplusDrain = new SettlementSurplusAuctioneer(address(accountingEngine), address(0));
    surplusAuctionHouseOne.addAuthorization(address(postSettlementSurplusDrain));

    accountingEngine.modifyParameters('postSettlementSurplusDrain', abi.encode(postSettlementSurplusDrain));
    safeEngine.addAuthorization(address(accountingEngine));

    debtAuctionHouse.modifyParameters('accountingEngine', address(accountingEngine));

    liquidationEngine = new LiquidationEngine(address(safeEngine));
    liquidationEngine.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    safeEngine.addAuthorization(address(liquidationEngine));
    accountingEngine.addAuthorization(address(liquidationEngine));

    oracleRelayer = new OracleRelayer(address(safeEngine));
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(rad(10_000_000 ether)));
    safeEngine.addAuthorization(address(oracleRelayer));

    stabilityFeeTreasury =
      new StabilityFeeTreasury(address(safeEngine), address(accountingEngine), address(systemCoinA));

    globalSettlement = new GlobalSettlement();
    globalSettlement.modifyParameters('safeEngine', address(safeEngine));
    globalSettlement.modifyParameters('liquidationEngine', address(liquidationEngine));
    globalSettlement.modifyParameters('accountingEngine', address(accountingEngine));
    globalSettlement.modifyParameters('oracleRelayer', address(oracleRelayer));
    globalSettlement.modifyParameters('shutdownCooldown', 1 hours);
    safeEngine.addAuthorization(address(globalSettlement));
    accountingEngine.addAuthorization(address(globalSettlement));
    oracleRelayer.addAuthorization(address(globalSettlement));
    liquidationEngine.addAuthorization(address(globalSettlement));
    stabilityFeeTreasury.addAuthorization(address(globalSettlement));
    surplusAuctionHouseOne.addAuthorization(address(accountingEngine));
    debtAuctionHouse.addAuthorization(address(accountingEngine));
  }

  function test_shutdown_basic() public {
    assertEq(globalSettlement.contractEnabled(), 1);
    assertEq(safeEngine.contractEnabled(), 1);
    assertEq(liquidationEngine.contractEnabled(), 1);
    assertEq(oracleRelayer.contractEnabled(), 1);
    assertEq(accountingEngine.contractEnabled(), 1);
    assertEq(accountingEngine.debtAuctionHouse().contractEnabled(), 1);
    assertEq(accountingEngine.surplusAuctionHouse().contractEnabled(), 1);
    globalSettlement.shutdownSystem();
    assertEq(globalSettlement.contractEnabled(), 0);
    assertEq(safeEngine.contractEnabled(), 0);
    assertEq(liquidationEngine.contractEnabled(), 0);
    assertEq(accountingEngine.contractEnabled(), 0);
    assertEq(oracleRelayer.contractEnabled(), 0);
    assertEq(accountingEngine.debtAuctionHouse().contractEnabled(), 0);
    assertEq(accountingEngine.surplusAuctionHouse().contractEnabled(), 0);
  }

  // -- Scenario where there is one over-collateralised SAFE
  // -- and there is no AccountingEngine deficit or surplus

  function test_shutdown_collateralised() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // collateral price is 5
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1);

    // local checks:
    assertEq(globalSettlement.finalCoinPerCollateralPrice('gold'), ray(0.2 ether));
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 7 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(15 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(15 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 7 ether);
    _ali.exit(gold.collateralA, address(this), 7 ether);

    hevm.warp(block.timestamp + 1 hours);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);

    // coin redemption
    _ali.approveSAFEModification(address(globalSettlement));
    _ali.prepareCoinsForRedeeming(15 ether);
    accountingEngine.settleDebt(rad(15 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), 0);
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    _ali.redeemCollateral('gold', 15 ether);

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 3 ether);
    _ali.exit(gold.collateralA, address(this), 3 ether);

    assertEq(tokenCollateral('gold', address(globalSettlement)), 0);
    assertEq(balanceOf('gold', address(gold.collateralA)), 0);
  }

  // -- Scenario where there is one over-collateralised and one
  // -- under-collateralised SAFE, and no AccountingEngine deficit or surplus
  function test_shutdown_undercollateralised() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);
    Usr _bob = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // make a second SAFE:
    address safe2 = address(_bob);
    gold.collateralA.join(safe2, 1 ether);
    _bob.modifySAFECollateralization('gold', safe2, safe2, safe2, 1 ether, 3 ether);

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(18 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // collateral price is 2
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(2 * WAD));
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1); // over-collateralised
    globalSettlement.processSAFE('gold', safe2); // under-collateralised

    // local checks
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 2.5 ether);
    assertEq(generatedDebt('gold', safe2), 0);
    assertEq(lockedCollateral('gold', safe2), 0);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(18 ether));

    // global checks
    assertEq(safeEngine.globalDebt(), rad(18 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(18 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 2.5 ether);
    _ali.exit(gold.collateralA, address(this), 2.5 ether);

    hevm.warp(block.timestamp + 1 hours);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);

    // first coin redemption
    _ali.approveSAFEModification(address(globalSettlement));
    _ali.prepareCoinsForRedeeming(15 ether);
    accountingEngine.settleDebt(rad(15 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(3 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(3 ether));

    _ali.redeemCollateral('gold', 15 ether);

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    uint256 fix = globalSettlement.collateralCashPrice('gold');
    assertEq(tokenCollateral('gold', _safe1), rmultiply(fix, 15 ether));
    _ali.exit(gold.collateralA, address(this), uint256(rmultiply(fix, 15 ether)));

    // second coin redemption
    _bob.approveSAFEModification(address(globalSettlement));
    _bob.prepareCoinsForRedeeming(3 ether);
    accountingEngine.settleDebt(rad(3 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), 0);
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    _bob.redeemCollateral('gold', 3 ether);

    // local checks:
    assertEq(coinBalance(safe2), 0);
    assertEq(tokenCollateral('gold', safe2), rmultiply(fix, 3 ether));
    _bob.exit(gold.collateralA, address(this), uint256(rmultiply(fix, 3 ether)));

    // some dust remains in GlobalSettlement because of rounding:
    assertEq(tokenCollateral('gold', address(globalSettlement)), 1);
    assertEq(balanceOf('gold', address(gold.collateralA)), 1);
  }

  // -- Scenario where there is one collateralised SAFE undergoing auction at the time of shutdown
  function test_shutdown_fast_track_collateral_auction() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    safeEngine.modifyParameters('gold', 'safetyPrice', abi.encode(ray(1 ether)));
    safeEngine.modifyParameters('gold', 'liquidationPrice', abi.encode(ray(1 ether))); // now unsafe

    uint256 auction = liquidationEngine.liquidateSAFE('gold', _safe1); // SAFE liquidated
    assertEq(safeEngine.globalUnbackedDebt(), rad(15 ether)); // now there is bad debt
    // get 5 coins from _ali
    _ali.transferInternalCoins(address(_ali), address(this), rad(5 ether));
    safeEngine.approveSAFEModification(address(gold.collateralAuctionHouse));
    assertEq(coinBalance(_safe1), 10 ether);

    (uint256 _collateralBought,) = gold.collateralAuctionHouse.getCollateralBought(auction, 5 ether);
    gold.collateralAuctionHouse.buyCollateral(auction, uint256(5 ether)); // bid 5 coin
    assertEq(tokenCollateral('gold', address(this)), _collateralBought);
    assertEq(_collateralBought, 26_315_789_473_684_210); // ~0.02 ether

    // collateral price is 5
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');

    globalSettlement.fastTrackAuction('gold', auction);
    assertEq(coinBalance(address(this)), 0); // bid refunded

    globalSettlement.processSAFE('gold', _safe1);

    // local checks:
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 7_973_684_210_526_315_790);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(20 ether));

    // balance the accountingEngine
    accountingEngine.settleDebt(
      minimum(safeEngine.coinBalance(address(accountingEngine)), safeEngine.debtBalance(address(accountingEngine)))
    );
    // global checks:
    assertEq(safeEngine.globalDebt(), rad(10 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(10 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 7_973_684_210_526_315_790);
    _ali.exit(gold.collateralA, address(this), 7_973_684_210_526_315_790);

    hevm.warp(block.timestamp + 1 hours);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);

    // coin redemption
    _ali.approveSAFEModification(address(globalSettlement));
    _ali.prepareCoinsForRedeeming(10 ether);
    accountingEngine.settleDebt(rad(10 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), 0);
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    _ali.redeemCollateral('gold', 10 ether);

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 2_000_000_000_000_000_000);
    _ali.exit(gold.collateralA, address(this), 2_000_000_000_000_000_000);
    gold.collateralA.exit(address(this), 26_315_789_473_684_210);

    assertEq(tokenCollateral('gold', address(globalSettlement)), 0);
    assertEq(balanceOf('gold', address(gold.collateralA)), 0);
  }

  // -- Scenario where there is one over-collateralised SAFE
  // -- and there is a deficit in the AccountingEngine
  function test_shutdown_collateralised_deficit() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // create 1 unbacked coin and give to _ali
    safeEngine.createUnbackedDebt(address(accountingEngine), address(_ali), rad(1 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(16 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(1 ether));

    // collateral price is 5
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1);

    // local checks:
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 7 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(16 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(16 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(16 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 7 ether);
    _ali.exit(gold.collateralA, address(this), 7 ether);

    hevm.warp(block.timestamp + 1 hours);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);

    // coin redemption
    _ali.approveSAFEModification(address(globalSettlement));
    _ali.prepareCoinsForRedeeming(16 ether);
    accountingEngine.settleDebt(rad(16 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), 0);
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    _ali.redeemCollateral('gold', 16 ether);

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 3 ether);
    _ali.exit(gold.collateralA, address(this), 3 ether);

    assertEq(tokenCollateral('gold', address(globalSettlement)), 0);
    assertEq(balanceOf('gold', address(gold.collateralA)), 0);
  }

  function test_shutdown_process_safe_has_bug() public {
    CollateralType memory gold = init_collateral('gold', 'gold');
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));

    Usr _ali = new Usr(safeEngine, globalSettlement);
    Usr _bob = new Usr(safeEngine, globalSettlement);
    Usr _charlie = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // transfer coins
    _ali.transferInternalCoins(address(_ali), address(_charlie), rad(2 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');

    // local checks:
    assertEq(globalSettlement.finalCoinPerCollateralPrice('gold'), ray(0.2 ether));
    assertEq(generatedDebt('gold', _safe1), 15 ether);
    assertEq(lockedCollateral('gold', _safe1), 10 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), 0);

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // transfer the remaining surplus with transferPostSettlementSurplus and continue the settlement process
    hevm.warp(block.timestamp + 1 hours);
    accountingEngine.transferPostSettlementSurplus();
    assertEq(globalSettlement.outstandingCoinSupply(), 0);
    globalSettlement.setOutstandingCoinSupply();

    // finish processing
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);

    // checks
    assertEq(safeEngine.tokenCollateral('gold', address(globalSettlement)), 0);
    assertEq(tokenCollateral('gold', address(_ali)), 0);
    assertEq(tokenCollateral('gold', address(_charlie)), 0);

    _charlie.approveSAFEModification(address(globalSettlement));
    assertEq(safeEngine.coinBalance(address(_charlie)), rad(2 ether));
  }

  function test_shutdown_overcollater_alized_surplus_smaller_redemption() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);
    Usr _bob = new Usr(safeEngine, globalSettlement);
    Usr _charlie = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // create surplus and also transfer to _charlie
    _ali.transferInternalCoins(address(_ali), address(accountingEngine), rad(2 ether));
    _ali.transferInternalCoins(address(_ali), address(_charlie), rad(2 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // collateral price is 5
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));
    // redemption price is 0.5
    oracleRelayer.modifyParameters('redemptionPrice', ray(0.5 ether));

    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1);

    // local checks:
    assertEq(globalSettlement.finalCoinPerCollateralPrice('gold'), ray(0.1 ether));
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 8.5 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(15 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(15 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 8.5 ether);
    _ali.exit(gold.collateralA, address(this), 8.5 ether);

    hevm.warp(block.timestamp + 1 hours);
    accountingEngine.settleDebt(safeEngine.coinBalance(address(accountingEngine)));
    assertEq(globalSettlement.outstandingCoinSupply(), 0);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);
    assertEq(safeEngine.tokenCollateral('gold', address(globalSettlement)), 1.5 ether);

    // coin redemption
    assertEq(tokenCollateral('gold', address(_ali)), 0);
    assertEq(tokenCollateral('gold', address(_charlie)), 0);

    _ali.approveSAFEModification(address(globalSettlement));
    assertEq(safeEngine.coinBalance(address(_ali)), rad(11 ether));
    _ali.prepareCoinsForRedeeming(11 ether);

    _charlie.approveSAFEModification(address(globalSettlement));
    assertEq(safeEngine.coinBalance(address(_charlie)), rad(2 ether));
    _charlie.prepareCoinsForRedeeming(2 ether);

    _ali.redeemCollateral('gold', 11 ether);
    _charlie.redeemCollateral('gold', 2 ether);

    assertEq(safeEngine.globalDebt(), rad(13 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(13 ether));

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 1_269_230_769_230_769_230);
    _ali.exit(gold.collateralA, address(this), tokenCollateral('gold', _safe1));

    assertEq(tokenCollateral('gold', address(_charlie)), 230_769_230_769_230_769);
    _charlie.exit(gold.collateralA, address(this), tokenCollateral('gold', address(_charlie)));

    assertEq(tokenCollateral('gold', address(globalSettlement)), 1);
    assertEq(balanceOf('gold', address(gold.collateralA)), 1);

    assertEq(coinBalance(address(postSettlementSurplusDrain)), 0);
  }

  function test_shutdown_overcollater_alized_surplus_bigger_redemption() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);
    Usr _bob = new Usr(safeEngine, globalSettlement);
    Usr _charlie = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // create surplus and also transfer to _charlie
    _ali.transferInternalCoins(address(_ali), address(accountingEngine), rad(2 ether));
    _ali.transferInternalCoins(address(_ali), address(_charlie), rad(2 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // collateral price is 5
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));
    // redemption price is 0.5
    oracleRelayer.modifyParameters('redemptionPrice', ray(2 ether));

    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1);

    // local checks:
    assertEq(globalSettlement.finalCoinPerCollateralPrice('gold'), ray(0.4 ether));
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 4 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(15 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(15 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(15 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 4 ether);
    _ali.exit(gold.collateralA, address(this), 4 ether);

    hevm.warp(block.timestamp + 1 hours);
    accountingEngine.settleDebt(safeEngine.coinBalance(address(accountingEngine)));
    assertEq(globalSettlement.outstandingCoinSupply(), 0);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);
    assertEq(safeEngine.tokenCollateral('gold', address(globalSettlement)), 6 ether);

    // coin redemption
    assertEq(tokenCollateral('gold', address(_ali)), 0);
    assertEq(tokenCollateral('gold', address(_charlie)), 0);

    _ali.approveSAFEModification(address(globalSettlement));
    assertEq(safeEngine.coinBalance(address(_ali)), rad(11 ether));
    _ali.prepareCoinsForRedeeming(11 ether);

    _charlie.approveSAFEModification(address(globalSettlement));
    assertEq(safeEngine.coinBalance(address(_charlie)), rad(2 ether));
    _charlie.prepareCoinsForRedeeming(2 ether);

    _ali.redeemCollateral('gold', 11 ether);
    _charlie.redeemCollateral('gold', 2 ether);

    assertEq(safeEngine.globalDebt(), rad(13 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(13 ether));

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 5_076_923_076_923_076_923);
    _ali.exit(gold.collateralA, address(this), tokenCollateral('gold', _safe1));

    assertEq(tokenCollateral('gold', address(_charlie)), 923_076_923_076_923_076);
    _charlie.exit(gold.collateralA, address(this), tokenCollateral('gold', address(_charlie)));

    assertEq(tokenCollateral('gold', address(globalSettlement)), 1);
    assertEq(balanceOf('gold', address(gold.collateralA)), 1);

    assertEq(coinBalance(address(postSettlementSurplusDrain)), 0);
  }

  // -- Scenario where there is one over-collateralised SAFE
  // -- and one under-collateralised SAFE and there is a
  // -- surplus in the AccountingEngine
  function test_shutdown_over_and_under_collateralised_surplus() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);
    Usr _bob = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // _alice gives one coin to the accountingEngine, creating surplus
    _ali.transferInternalCoins(address(_ali), address(accountingEngine), rad(1 ether));
    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(1 ether));

    // make a second SAFE:
    address safe2 = address(_bob);
    gold.collateralA.join(safe2, 1 ether);
    _bob.modifySAFECollateralization('gold', safe2, safe2, safe2, 1 ether, 3 ether);

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(18 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // collateral price is 2
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(2 * WAD));
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1); // over-collateralised
    globalSettlement.processSAFE('gold', safe2); // under-collateralised

    // local checks
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 2.5 ether);
    assertEq(generatedDebt('gold', safe2), 0);
    assertEq(lockedCollateral('gold', safe2), 0);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(18 ether));

    // global checks
    assertEq(safeEngine.globalDebt(), rad(18 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(18 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 2.5 ether);
    _ali.exit(gold.collateralA, address(this), 2.5 ether);

    hevm.warp(block.timestamp + 1 hours);
    // balance the accountingEngine using transferPostSettlementSurplus
    accountingEngine.transferPostSettlementSurplus();
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    assertTrue(globalSettlement.collateralCashPrice('gold') != 0);

    // first coin redemption
    _ali.approveSAFEModification(address(globalSettlement));
    _ali.prepareCoinsForRedeeming(coinBalance(address(_ali)));
    accountingEngine.settleDebt(rad(14 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(3 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(3 ether));

    _ali.redeemCollateral('gold', 14 ether);

    // local checks:
    assertEq(coinBalance(_safe1), 0);
    uint256 fix = globalSettlement.collateralCashPrice('gold');
    assertEq(tokenCollateral('gold', _safe1), uint256(rmultiply(fix, 14 ether)));
    _ali.exit(gold.collateralA, address(this), uint256(rmultiply(fix, 14 ether)));

    // second coin redemption
    _bob.approveSAFEModification(address(globalSettlement));
    _bob.prepareCoinsForRedeeming(3 ether);
    accountingEngine.settleDebt(rad(3 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), 0);
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    _bob.redeemCollateral('gold', 3 ether);

    // local checks:
    assertEq(coinBalance(safe2), 0);
    assertEq(tokenCollateral('gold', safe2), rmultiply(fix, 3 ether));
    _bob.exit(gold.collateralA, address(this), uint256(rmultiply(fix, 3 ether)));

    // nothing left in the GlobalSettlement
    assertEq(tokenCollateral('gold', address(globalSettlement)), 0);
    assertEq(balanceOf('gold', address(gold.collateralA)), 0);

    assertEq(coinBalance(address(postSettlementSurplusDrain)), 0);
  }

  // -- Scenario where there is one over-collateralised and one
  // -- under-collateralised SAFE of different collateral types
  // -- and no AccountingEngine deficit or surplus
  function test_shutdown_net_undercollateralised_multiple_collateralTypes() public {
    CollateralType memory gold = init_collateral('gold', 'gold');
    CollateralType memory coal = init_collateral('coal', 'coal');

    Usr _ali = new Usr(safeEngine, globalSettlement);
    Usr _bob = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateralA.join(_safe1, 10 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 10 ether, 15 ether);

    // make a second SAFE:
    address safe2 = address(_bob);
    coal.collateralA.join(safe2, 1 ether);
    safeEngine.modifyParameters('coal', 'safetyPrice', abi.encode(ray(5 ether)));
    _bob.modifySAFECollateralization('coal', safe2, safe2, safe2, 1 ether, 5 ether);

    gold.oracleSecurityModule.updateCollateralPrice(bytes32(2 * WAD));
    // _safe1 has 20 coin of lockedCollateral and 15 coin of tab
    coal.oracleSecurityModule.updateCollateralPrice(bytes32(2 * WAD));
    // safe2 has 2 coin of lockedCollateral and 5 coin of tab
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.freezeCollateralType('coal');
    globalSettlement.processSAFE('gold', _safe1); // over-collateralised
    globalSettlement.processSAFE('coal', safe2); // under-collateralised

    hevm.warp(block.timestamp + 1 hours);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
    globalSettlement.calculateCashPrice('coal');

    _ali.approveSAFEModification(address(globalSettlement));
    _bob.approveSAFEModification(address(globalSettlement));

    assertEq(safeEngine.globalDebt(), rad(20 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(20 ether));
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(20 ether));

    assertEq(globalSettlement.collateralTotalDebt('gold'), 15 ether);
    assertEq(globalSettlement.collateralTotalDebt('coal'), 5 ether);

    assertEq(globalSettlement.collateralShortfall('gold'), 0.0 ether);
    assertEq(globalSettlement.collateralShortfall('coal'), 1.5 ether);

    // there are 7.5 gold and 1 coal
    // the gold is worth 15 coin and the coal is worth 2 coin
    // the total collateral pool is worth 17 coin
    // the total outstanding debt is 20 coin
    // each coin should get (15/2)/20 gold and (2/2)/20 coal
    assertEq(globalSettlement.collateralCashPrice('gold'), ray(0.375 ether));
    assertEq(globalSettlement.collateralCashPrice('coal'), ray(0.05 ether));

    assertEq(tokenCollateral('gold', address(_ali)), 0 ether);
    _ali.prepareCoinsForRedeeming(1 ether);
    _ali.redeemCollateral('gold', 1 ether);
    assertEq(tokenCollateral('gold', address(_ali)), 0.375 ether);

    _bob.prepareCoinsForRedeeming(1 ether);
    _bob.redeemCollateral('coal', 1 ether);
    assertEq(tokenCollateral('coal', address(_bob)), 0.05 ether);

    _ali.exit(gold.collateralA, address(_ali), 0.375 ether);
    _bob.exit(coal.collateralA, address(_bob), 0.05 ether);
    _ali.prepareCoinsForRedeeming(1 ether);
    _ali.redeemCollateral('gold', 1 ether);
    _ali.redeemCollateral('coal', 1 ether);
    assertEq(tokenCollateral('gold', address(_ali)), 0.375 ether);
    assertEq(tokenCollateral('coal', address(_ali)), 0.05 ether);

    _ali.exit(gold.collateralA, address(_ali), 0.375 ether);
    _ali.exit(coal.collateralA, address(_ali), 0.05 ether);

    _ali.prepareCoinsForRedeeming(1 ether);
    _ali.redeemCollateral('gold', 1 ether);
    assertEq(globalSettlement.coinsUsedToRedeem('gold', address(_ali)), 3 ether);
    assertEq(globalSettlement.coinsUsedToRedeem('coal', address(_ali)), 1 ether);
    _ali.prepareCoinsForRedeeming(1 ether);
    _ali.redeemCollateral('coal', 1 ether);
    assertEq(globalSettlement.coinsUsedToRedeem('gold', address(_ali)), 3 ether);
    assertEq(globalSettlement.coinsUsedToRedeem('coal', address(_ali)), 2 ether);
    assertEq(tokenCollateral('gold', address(_ali)), 0.375 ether);
    assertEq(tokenCollateral('coal', address(_ali)), 0.05 ether);
  }

  // -- Scenario where calculateCashPrice() used to overflow
  function test_calculateCashPrice_overflow() public {
    CollateralType memory gold = init_collateral('gold', 'gold');

    Usr _ali = new Usr(safeEngine, globalSettlement);

    // make a SAFE:
    address _safe1 = address(_ali);
    gold.collateral.mint(500_000_000 ether);
    gold.collateralA.join(_safe1, 500_000_000 ether);
    _ali.modifySAFECollateralization('gold', _safe1, _safe1, _safe1, 500_000_000 ether, 10_000_000 ether);
    // _ali's urn has 500_000_000 collateral, 10^7 debt (and 10^7 system coins since rate == RAY)

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(10_000_000 ether));
    assertEq(safeEngine.globalUnbackedDebt(), 0);

    // collateral price is 5
    gold.oracleSecurityModule.updateCollateralPrice(bytes32(5 * WAD));
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType('gold');
    globalSettlement.processSAFE('gold', _safe1);

    // local checks:
    assertEq(generatedDebt('gold', _safe1), 0);
    assertEq(lockedCollateral('gold', _safe1), 498_000_000 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), rad(10_000_000 ether));

    // global checks:
    assertEq(safeEngine.globalDebt(), rad(10_000_000 ether));
    assertEq(safeEngine.globalUnbackedDebt(), rad(10_000_000 ether));

    // SAFE closing
    _ali.freeCollateral('gold');
    assertEq(lockedCollateral('gold', _safe1), 0);
    assertEq(tokenCollateral('gold', _safe1), 498_000_000 ether);
    _ali.exit(gold.collateralA, address(this), 498_000_000 ether);

    hevm.warp(block.timestamp + 1 hours);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('gold');
  }
}
