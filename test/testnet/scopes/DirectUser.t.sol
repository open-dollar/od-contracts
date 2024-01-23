// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ScriptBase} from 'forge-std/Script.sol';
import {ETH_A} from '@script/Params.s.sol';
import {
  Contracts,
  ICollateralJoin,
  MintableERC20,
  IERC20Metadata,
  ISAFEEngine,
  ICollateralAuctionHouse
} from '@script/Contracts.s.sol';
import {IWeth} from '@interfaces/external/IWeth.sol';
import {SEPOLIA_WETH} from '@script/Registry.s.sol';
import {BaseUser} from '@testnet/scopes/BaseUser.t.sol';

abstract contract DirectUser is BaseUser, Contracts, ScriptBase {
  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal view override returns (uint256 _generatedDebt, uint256 _lockedCollateral) {
    ISAFEEngine.SAFE memory _safe = safeEngine.safes(_cType, _user);
    _generatedDebt = _safe.generatedDebt;
    _lockedCollateral = _safe.lockedCollateral;
  }

  function _getSafeHandler(bytes32, address _user) internal pure override returns (address _safeHandler) {
    return _user;
  }

  function _getCollateralBalance(address _user, bytes32 _cType) internal view override returns (uint256 _wad) {
    IERC20Metadata _collateral = collateral[_cType];
    uint256 _decimals = _collateral.decimals();
    uint256 _wei = _collateral.balanceOf(_user);
    _wad = _wei * 10 ** (18 - _decimals);
  }

  function _getInternalCoinBalance(address _user) internal view override returns (uint256 _rad) {
    _rad = safeEngine.coinBalance(_user);
  }

  // --- SAFE actions ---

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal override {
    IERC20Metadata _collateral = ICollateralJoin(_collateralJoin).collateral();
    uint256 _decimals = _collateral.decimals();
    uint256 _wei = _amount / 10 ** (18 - _decimals);

    vm.startPrank(_user);
    if (address(_collateral) != SEPOLIA_WETH) {
      MintableERC20(address(_collateral)).mint(_user, _wei);
    } else {
      vm.deal(_user, _wei);
      IWeth(address(_collateral)).deposit{value: _wei}();
    }

    _collateral.approve(address(_collateralJoin), _wei);
    ICollateralJoin(_collateralJoin).join(_user, _wei);
    vm.stopPrank();
  }

  function _exitCollateral(address _user, address _collateralJoin, uint256 _amount) internal override {
    uint256 _decimals = ICollateralJoin(_collateralJoin).decimals();
    uint256 _wei = _amount / 10 ** (18 - _decimals);

    vm.prank(_user);
    ICollateralJoin(_collateralJoin).exit(_user, _wei);
  }

  function _joinCoins(address _user, uint256 _amount) internal override {
    vm.startPrank(_user);
    systemCoin.approve(address(coinJoin), _amount);
    coinJoin.join(_user, _amount);
    vm.stopPrank();
  }

  function _exitCoin(address _user, uint256 _amount) internal override {
    vm.startPrank(_user);
    safeEngine.approveSAFEModification(address(coinJoin));
    coinJoin.exit(_user, _amount);
    vm.stopPrank();
  }

  function _liquidateSAFE(bytes32 _cType, address _user) internal override {
    liquidationEngine.liquidateSAFE(_cType, _user);
  }

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _deltaCollat,
    int256 _deltaDebt
  ) internal override {
    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    bytes32 _cType = __collateralJoin.collateralType();

    _joinTKN(_user, _collateralJoin, uint256(_deltaCollat));

    vm.startPrank(_user);
    safeEngine.approveSAFEModification(_collateralJoin);
    safeEngine.modifySAFECollateralization({
      _cType: ICollateralJoin(_collateralJoin).collateralType(),
      _safe: _user,
      _collateralSource: _user,
      _debtDestination: _user,
      _deltaCollateral: _deltaCollat,
      _deltaDebt: _deltaDebt
    });
    vm.stopPrank();

    // already pranked call
    _exitCoin(_user, uint256(_deltaDebt));
  }

  function _repayDebtAndExit(
    address _user,
    address _collateralJoin,
    uint256 _deltaCollat,
    uint256 _deltaDebt
  ) internal override {
    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    bytes32 _cType = __collateralJoin.collateralType();

    vm.startPrank(_user);
    systemCoin.approve(address(coinJoin), _deltaDebt);
    coinJoin.join(_user, _deltaDebt);

    safeEngine.modifySAFECollateralization({
      _cType: _cType,
      _safe: _user,
      _collateralSource: _user,
      _debtDestination: _user,
      _deltaCollateral: -int256(_deltaCollat),
      _deltaDebt: -int256(_deltaDebt)
    });
    vm.stopPrank();

    _exitCollateral(_user, _collateralJoin, _deltaCollat);
  }

  // --- Bidding actions ---

  function _buyCollateral(
    address _user,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _soldAmount,
    uint256 _amountToBid
  ) internal override {
    vm.startPrank(_user);
    safeEngine.approveSAFEModification(_collateralAuctionHouse);
    ICollateralAuctionHouse(_collateralAuctionHouse).buyCollateral(_auctionId, _amountToBid);

    // exit collateral
    bytes32 _cType = ICollateralAuctionHouse(_collateralAuctionHouse).collateralType();
    uint256 _decimals = ICollateralJoin(collateralJoin[_cType]).decimals();
    uint256 _collateralWei = _soldAmount / 10 ** (18 - _decimals);
    ICollateralJoin(collateralJoin[_cType]).exit(_user, _collateralWei);
    vm.stopPrank();
  }

  function _buyProtocolToken(
    address _user,
    uint256 _auctionId,
    uint256 _amountToBuy,
    uint256 _amountToBid
  ) internal override {
    vm.startPrank(_user);
    systemCoin.approve(address(coinJoin), _amountToBid / 1e27);
    coinJoin.join(_user, _amountToBid / 1e27);
    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    debtAuctionHouse.decreaseSoldAmount(_auctionId, _amountToBuy);
    vm.stopPrank();
  }

  function _settleDebtAuction(address _user, uint256 _auctionId) internal override {
    debtAuctionHouse.settleAuction(_auctionId);
  }

  function _increaseBidSize(address _user, uint256 _auctionId, uint256 _bidAmount) internal override {
    vm.startPrank(_user);
    protocolToken.approve(address(surplusAuctionHouse), _bidAmount);
    surplusAuctionHouse.increaseBidSize(_auctionId, _bidAmount);
    vm.stopPrank();
  }

  function _settleSurplusAuction(address _user, uint256 _auctionId) internal override {
    surplusAuctionHouse.settleAuction(_auctionId);

    _collectSystemCoins(_user);
  }

  function _collectSystemCoins(address _user) internal override {
    uint256 _systemCoinInternalBalance = safeEngine.coinBalance(_user);

    _exitCoin(_user, _systemCoinInternalBalance / 1e27);
  }

  // --- Global Settlement actions ---

  function _increasePostSettlementBidSize(address _user, uint256 _auctionId, uint256 _bidAmount) internal override {
    vm.startPrank(_user);
    protocolToken.approve(address(postSettlementSurplusAuctionHouse), _bidAmount);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auctionId, _bidAmount);
    vm.stopPrank();
  }

  function _settlePostSettlementSurplusAuction(address _user, uint256 _auctionId) internal override {
    postSettlementSurplusAuctionHouse.settleAuction(_auctionId);
  }

  function _freeCollateral(address _user, bytes32 _cType) internal override returns (uint256 _remainderCollateral) {
    globalSettlement.processSAFE(_cType, _user);

    _remainderCollateral = safeEngine.safes(_cType, _user).lockedCollateral;
    if (_remainderCollateral > 0) {
      vm.prank(_user);
      globalSettlement.freeCollateral(_cType);
      _exitCollateral(_user, address(collateralJoin[_cType]), _remainderCollateral);
    }
  }

  function _prepareCoinsForRedeeming(address _user, uint256 _amount) internal override {
    uint256 _internalCoins = safeEngine.coinBalance(_user) / 1e27;
    uint256 _coinsToJoin = _internalCoins >= _amount ? 0 : _amount - _internalCoins;

    _joinCoins(_user, _coinsToJoin); // has prank
    vm.startPrank(_user);
    safeEngine.approveSAFEModification(address(globalSettlement));
    globalSettlement.prepareCoinsForRedeeming(_amount);
    vm.stopPrank();
  }

  function _redeemCollateral(
    address _user,
    bytes32 _cType,
    uint256 _coinsAmount
  ) internal override returns (uint256 _collateralAmount) {
    vm.prank(_user);
    globalSettlement.redeemCollateral(_cType, _coinsAmount);

    _collateralAmount = safeEngine.tokenCollateral(_cType, _user);
    _exitCollateral(_user, address(collateralJoin[_cType]), _collateralAmount);
  }

  // --- Rewarded actions ---

  function _workPopDebtFromQueue(address _user, uint256 _debtBlockTimestamp) internal override {
    vm.prank(_user);
    accountingJob.workPopDebtFromQueue(_debtBlockTimestamp);

    _collectSystemCoins(_user);
  }

  function _workAuctionDebt(address _user) internal override {
    vm.prank(_user);
    accountingJob.workAuctionDebt();

    _collectSystemCoins(_user);
  }

  function _workAuctionSurplus(address _user) internal override {
    vm.prank(_user);
    accountingJob.workAuctionSurplus();

    _collectSystemCoins(_user);
  }

  function _workLiquidation(address _user, bytes32 _cType, address _safe) internal override {
    vm.prank(_user);
    liquidationJob.workLiquidation(_cType, _safe);

    _collectSystemCoins(_user);
  }

  function _workUpdateCollateralPrice(address _user, bytes32 _cType) internal override {
    vm.prank(_user);
    oracleJob.workUpdateCollateralPrice(_cType);

    _collectSystemCoins(_user);
  }

  function _workUpdateRate(address _user) internal override {
    vm.prank(_user);
    oracleJob.workUpdateRate();

    _collectSystemCoins(_user);
  }
}
