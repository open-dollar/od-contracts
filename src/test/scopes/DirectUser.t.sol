// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ScriptBase} from 'forge-std/Script.sol';
import {ETH_A} from '@script/Params.s.sol';
import {
  Contracts,
  ICollateralJoin,
  ERC20ForTest,
  IERC20Metadata,
  ISAFEEngine,
  ICollateralAuctionHouse
} from '@script/Contracts.s.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';

abstract contract DirectUser is BaseUser, Contracts, ScriptBase {
  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal virtual override returns (uint256 _generatedDebt, uint256 _lockedCollateral) {
    ISAFEEngine.SAFE memory _safe = safeEngine.safes(_cType, _user);
    _generatedDebt = _safe.generatedDebt;
    _lockedCollateral = _safe.lockedCollateral;
  }

  function _lockETH(address _user, uint256 _amount) internal virtual override {
    vm.startPrank(_user);

    vm.deal(_user, _amount);
    ethJoin.join{value: _amount}(_user);

    vm.stopPrank();
  }

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal virtual override {
    vm.startPrank(_user);
    IERC20Metadata _collateral = ICollateralJoin(_collateralJoin).collateral();

    ERC20ForTest(address(_collateral)).mint(_user, _amount);

    _collateral.approve(address(_collateralJoin), _amount);
    ICollateralJoin(_collateralJoin).join(_user, _amount);
    vm.stopPrank();
  }

  function _joinCoins(address _user, uint256 _amount) internal virtual override {
    vm.startPrank(_user);
    systemCoin.approve(address(coinJoin), _amount);
    coinJoin.join(_user, _amount);
    vm.stopPrank();
  }

  function _exitCoin(address _user, uint256 _amount) internal virtual override {
    vm.startPrank(_user);
    safeEngine.approveSAFEModification(address(coinJoin));
    coinJoin.exit(_user, _amount);
    vm.stopPrank();
  }

  function _liquidateSAFE(bytes32 _cType, address _user) internal virtual override {
    liquidationEngine.liquidateSAFE(_cType, _user);
  }

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _deltaCollat,
    int256 _deltaDebt
  ) internal virtual override {
    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    bytes32 _cType = __collateralJoin.collateralType();
    if (_cType == ETH_A) _lockETH(_user, uint256(_deltaCollat));
    else _joinTKN(_user, _collateralJoin, uint256(_deltaCollat));

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

    _exitCoin(_user, uint256(_deltaDebt));
  }

  function _buyCollateral(
    address _user,
    address,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _amountToBid
  ) internal override {
    vm.startPrank(_user);
    safeEngine.approveSAFEModification(_collateralAuctionHouse);
    ICollateralAuctionHouse(_collateralAuctionHouse).buyCollateral(_auctionId, _amountToBid);
    vm.stopPrank();
  }

  function _buyProtocolToken(
    address _user,
    uint256 _auctionId,
    uint256 _amountToBuy,
    uint256 _amountToBid
  ) internal override {
    vm.startPrank(_user);
    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    debtAuctionHouse.decreaseSoldAmount(_auctionId, _amountToBuy, _amountToBid);
    vm.stopPrank();
  }

  function _settleDebtAuction(address, uint256 _auctionId) internal override {
    debtAuctionHouse.settleAuction(_auctionId);
  }

  function _buySystemCoin(address _user, uint256 _auctionId, uint256 _amountToBid) internal override {
    // TODO: missing SurplusAuctionHouse E2E test
  }
}
