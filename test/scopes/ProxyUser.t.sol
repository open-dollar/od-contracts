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
  ICollateralAuctionHouse,
  BasicActions,
  DebtBidActions,
  SurplusBidActions,
  CollateralBidActions,
  PostSettlementSurplusBidActions,
  GlobalSettlementActions,
  RewardedActions,
  CommonActions,
  HaiProxy
} from '@script/Contracts.s.sol';
import {OP_WETH} from '@script/Registry.s.sol';
import {IWeth} from '@interfaces/external/IWeth.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';

abstract contract ProxyUser is BaseUser, Contracts, ScriptBase {
  mapping(address => HaiProxy) private proxy;
  mapping(address => mapping(bytes32 => uint256)) private safe;
  mapping(address => mapping(bytes32 => address)) private safeHandler;

  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal override returns (uint256 _generatedDebt, uint256 _lockedCollateral) {
    (uint256 _safeId,) = _getSafe(_user, _cType);
    address _safeHandler = safeManager.safeData(_safeId).safeHandler;

    ISAFEEngine.SAFE memory _safe = safeEngine.safes(_cType, _safeHandler);
    _generatedDebt = _safe.generatedDebt;
    _lockedCollateral = _safe.lockedCollateral;
  }

  function _getSafeHandler(bytes32 _cType, address _user) internal override returns (address _safeHandler) {
    (, _safeHandler) = _getSafe(_user, _cType);
  }

  function _getCollateralBalance(address _user, bytes32 _cType) internal view override returns (uint256 _wad) {
    IERC20Metadata _collateral = collateral[_cType];
    uint256 _decimals = _collateral.decimals();
    uint256 _wei = _collateral.balanceOf(_user);
    _wad = _wei * 10 ** (18 - _decimals);
  }

  function _getInternalCoinBalance(address _user) internal override returns (uint256 _rad) {
    HaiProxy _proxy = _getProxy(_user);
    _rad = safeEngine.coinBalance(address(_proxy));
  }

  // --- SAFE actions ---

  function _lockETH(address _user, uint256 _collatAmount) internal override {
    HaiProxy _proxy = _getProxy(_user);
    (uint256 _safeId,) = _getSafe(_user, ETH_A);

    vm.startPrank(_user);
    IWeth(address(collateral[ETH_A])).deposit{value: _collatAmount}();
    collateral[ETH_A].approve(address(_proxy), _collatAmount);

    // NOTE: missing for ETH implementation (should add value to msg)
    // bytes memory _callData = abi.encodeWithSelector(
    //   BasicActions.lockTokenCollateral.selector,
    //   address(safeManager),
    //   address(collateralJoin[ETH_A]),
    //   _safeId,
    //   _collatAmount,
    //   true
    // );
    // _proxy.execute(address(basicActions), _callData);
    vm.stopPrank();
  }

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal override {
    // NOTE: proxy implementation only needs approval for operating with the collateral
    HaiProxy _proxy = _getProxy(_user);

    IERC20Metadata _collateral = ICollateralJoin(_collateralJoin).collateral();
    uint256 _decimals = _collateral.decimals();
    uint256 _wei = _amount / 10 ** (18 - _decimals);

    vm.startPrank(_user);
    if (address(_collateral) != OP_WETH) {
      MintableERC20(address(_collateral)).mint(_user, _wei);
    } else {
      vm.deal(_user, _wei);
      IWeth(address(_collateral)).deposit{value: _wei}();
    }

    _collateral.approve(address(_proxy), _wei);
    vm.stopPrank();
  }

  function _exitCollateral(address _user, address _collateralJoin, uint256 _amount) internal override {
    // NOTE: proxy implementation already exits collateral
  }

  function _joinCoins(address _user, uint256 _amount) internal override {
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    systemCoin.approve(address(_proxy), _amount);

    bytes memory _callData =
      abi.encodeWithSelector(CommonActions.joinSystemCoins.selector, address(coinJoin), _user, _amount);

    _proxy.execute(address(basicActions), _callData);
    vm.stopPrank();
  }

  function _exitCoin(address _user, uint256 _amount) internal override {
    // NOTE: proxy implementation already exits coins
  }

  function _liquidateSAFE(bytes32 _cType, address _user) internal override {
    (, address _safeHandler) = _getSafe(_user, _cType);
    liquidationEngine.liquidateSAFE(_cType, _safeHandler);
  }

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _collatAmount,
    int256 _deltaDebt
  ) internal override {
    HaiProxy _proxy = _getProxy(_user);
    bytes32 _cType = ICollateralJoin(_collateralJoin).collateralType();
    (uint256 _safeId,) = _getSafe(_user, _cType);

    if (_cType == ETH_A) _lockETH(_user, uint256(_collatAmount));
    else _joinTKN(_user, _collateralJoin, uint256(_collatAmount));

    bytes memory _callData = abi.encodeWithSelector(
      BasicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaDebt // wad
    );

    vm.prank(_user);
    _proxy.execute(address(basicActions), _callData);
  }

  function _repayDebtAndExit(
    address _user,
    address _collateralJoin,
    uint256 _deltaCollat,
    uint256 _deltaDebt
  ) internal override {
    HaiProxy _proxy = _getProxy(_user);
    bytes32 _cType = ICollateralJoin(_collateralJoin).collateralType();
    (uint256 _safeId,) = _getSafe(_user, _cType);

    vm.startPrank(_user);
    systemCoin.approve(address(_proxy), _deltaDebt);

    bytes memory _callData = abi.encodeWithSelector(
      BasicActions.repayDebtAndFreeTokenCollateral.selector,
      address(safeManager),
      address(taxCollector),
      _collateralJoin,
      address(coinJoin),
      _safeId,
      _deltaCollat,
      _deltaDebt
    );

    _proxy.execute(address(basicActions), _callData);
    vm.stopPrank();
  }

  function _getProxy(address _user) internal returns (HaiProxy) {
    if (proxy[_user] == HaiProxy(address(0))) {
      proxy[_user] = HaiProxy(proxyFactory.build(_user));
    }
    return proxy[_user];
  }

  function _getSafe(address _user, bytes32 _cType) internal returns (uint256 _safeId, address _safeHandler) {
    HaiProxy _proxy = _getProxy(_user);

    if (safe[_user][_cType] == 0) {
      bytes memory _callData =
        abi.encodeWithSelector(BasicActions.openSAFE.selector, address(safeManager), _cType, address(_proxy));

      vm.prank(_user);
      (bytes memory _response) = _proxy.execute(address(basicActions), _callData);
      _safeId = abi.decode(_response, (uint256));
      _safeHandler = safeManager.safeData(_safeId).safeHandler;

      // store safeId and safeHandler in local storage
      safe[_user][_cType] = _safeId;
      safeHandler[_user][_cType] = _safeHandler;
    }

    return (safe[_user][_cType], safeHandler[_user][_cType]);
  }

  // --- Bidding actions ---

  function _buyCollateral(
    address _user,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _soldAmount,
    uint256 _amountToBid
  ) internal override {
    HaiProxy _proxy = _getProxy(_user);
    _joinCoins(_user, _amountToBid);

    vm.startPrank(_user);
    systemCoin.approve(address(_proxy), _amountToBid);
    bytes memory _callData = abi.encodeWithSelector(
      CollateralBidActions.buyCollateral.selector,
      coinJoin,
      collateralJoin[ICollateralAuctionHouse(_collateralAuctionHouse).collateralType()],
      _collateralAuctionHouse,
      _auctionId,
      _soldAmount,
      _amountToBid
    );

    _proxy.execute(address(collateralBidActions), _callData);
    vm.stopPrank();
  }

  function _buyProtocolToken(
    address _user,
    uint256 _auctionId,
    uint256 _amountToBuy,
    uint256 _amountToBid
  ) internal override {
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    systemCoin.approve(address(_proxy), _amountToBid);
    bytes memory _callData = abi.encodeWithSelector(
      DebtBidActions.decreaseSoldAmount.selector, coinJoin, debtAuctionHouse, _auctionId, _amountToBuy
    );

    _proxy.execute(address(debtBidActions), _callData);
    vm.stopPrank();
  }

  function _settleDebtAuction(address _user, uint256 _auctionId) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData =
      abi.encodeWithSelector(DebtBidActions.settleAuction.selector, coinJoin, debtAuctionHouse, _auctionId);

    vm.prank(_user);
    _proxy.execute(address(debtBidActions), _callData);
  }

  function _increaseBidSize(address _user, uint256 _auctionId, uint256 _bidAmount) internal override {
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    protocolToken.approve(address(_proxy), _bidAmount);

    bytes memory _callData = abi.encodeWithSelector(
      SurplusBidActions.increaseBidSize.selector, address(surplusAuctionHouse), _auctionId, _bidAmount
    );

    _proxy.execute(address(surplusBidActions), _callData);
    vm.stopPrank();
  }

  function _settleSurplusAuction(address _user, uint256 _auctionId) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData = abi.encodeWithSelector(
      SurplusBidActions.settleAuction.selector, address(coinJoin), address(surplusAuctionHouse), _auctionId
    );

    vm.prank(_user);
    _proxy.execute(address(surplusBidActions), _callData);
  }

  function _collectSystemCoins(address _user) internal override {
    HaiProxy _proxy = _getProxy(_user);

    uint256 _coinsToExit = safeEngine.coinBalance(address(_proxy));

    bytes memory _callData =
      abi.encodeWithSelector(CommonActions.exitSystemCoins.selector, address(coinJoin), _coinsToExit);

    vm.prank(_user);
    _proxy.execute(address(surplusBidActions), _callData);
  }

  // --- Global Settlement actions ---

  function _increasePostSettlementBidSize(address _user, uint256 _auctionId, uint256 _bidAmount) internal override {
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    protocolToken.approve(address(_proxy), _bidAmount);

    bytes memory _callData = abi.encodeWithSelector(
      SurplusBidActions.increaseBidSize.selector, address(postSettlementSurplusAuctionHouse), _auctionId, _bidAmount
    );

    _proxy.execute(address(postSettlementSurplusBidActions), _callData);
    vm.stopPrank();
  }

  function _settlePostSettlementSurplusAuction(address _user, uint256 _auctionId) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData = abi.encodeWithSelector(
      SurplusBidActions.settleAuction.selector,
      address(globalSettlement),
      address(postSettlementSurplusAuctionHouse),
      _auctionId
    );

    vm.prank(_user);
    _proxy.execute(address(postSettlementSurplusBidActions), _callData);
  }

  function _freeCollateral(address _user, bytes32 _cType) internal override returns (uint256 _remainderCollateral) {
    HaiProxy _proxy = _getProxy(_user);
    (uint256 _safeId,) = _getSafe(_user, _cType);

    bytes memory _callData = abi.encodeWithSelector(
      GlobalSettlementActions.freeCollateral.selector, safeManager, globalSettlement, collateralJoin[_cType], _safeId
    );

    vm.prank(_user);
    bytes memory _response = _proxy.execute(address(globalSettlementActions), _callData);
    _remainderCollateral = abi.decode(_response, (uint256));
  }

  function _prepareCoinsForRedeeming(address _user, uint256 _amount) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData = abi.encodeWithSelector(
      GlobalSettlementActions.prepareCoinsForRedeeming.selector, globalSettlement, coinJoin, _amount
    );

    vm.startPrank(_user);
    systemCoin.approve(address(_proxy), _amount);
    _proxy.execute(address(globalSettlementActions), _callData);
    vm.stopPrank();
  }

  function _redeemCollateral(
    address _user,
    bytes32 _cType,
    uint256 _coinsAmount
  ) internal override returns (uint256 _collateralAmount) {
    HaiProxy _proxy = _getProxy(_user);

    // NOTE: proxy implementation uses all available coins in bag
    bytes memory _callData = abi.encodeWithSelector(
      GlobalSettlementActions.redeemCollateral.selector, globalSettlement, collateralJoin[_cType]
    );

    vm.prank(_user);
    bytes memory _response = _proxy.execute(address(globalSettlementActions), _callData);
    _collateralAmount = abi.decode(_response, (uint256));
  }

  // --- Rewarded actions ---

  function _workPopDebtFromQueue(address _user, uint256 _debtBlockTimestamp) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData = abi.encodeWithSelector(
      RewardedActions.popDebtFromQueue.selector, address(accountingJob), address(coinJoin), _debtBlockTimestamp
    );

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }

  function _workAuctionDebt(address _user) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData =
      abi.encodeWithSelector(RewardedActions.startDebtAuction.selector, address(accountingJob), address(coinJoin));

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }

  function _workAuctionSurplus(address _user) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData =
      abi.encodeWithSelector(RewardedActions.startSurplusAuction.selector, address(accountingJob), address(coinJoin));

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }

  function _workTransferExtraSurplus(address _user) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData =
      abi.encodeWithSelector(RewardedActions.transferExtraSurplus.selector, address(accountingJob), address(coinJoin));

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }

  function _workLiquidation(address _user, bytes32 _cType, address _safe) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData = abi.encodeWithSelector(
      RewardedActions.liquidateSAFE.selector, address(liquidationJob), address(coinJoin), _cType, _safe
    );

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }

  function _workUpdateCollateralPrice(address _user, bytes32 _cType) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData = abi.encodeWithSelector(
      RewardedActions.updateCollateralPrice.selector, address(oracleJob), address(coinJoin), _cType
    );

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }

  function _workUpdateRate(address _user) internal override {
    HaiProxy _proxy = _getProxy(_user);

    bytes memory _callData =
      abi.encodeWithSelector(RewardedActions.updateRedemptionRate.selector, address(oracleJob), address(coinJoin));

    vm.prank(_user);
    _proxy.execute(address(rewardedActions), _callData);
  }
}
