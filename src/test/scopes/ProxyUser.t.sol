// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ScriptBase} from 'forge-std/Script.sol';
import {ETH_A} from '@script/Params.s.sol';
import {
  Contracts,
  ICoinJoin,
  ICollateralJoin,
  ERC20ForTest,
  IERC20Metadata,
  ISAFEEngine,
  ICollateralAuctionHouse,
  IDebtAuctionHouse,
  BasicActions,
  CommonActions,
  HaiProxy
} from '@script/Contracts.s.sol';
import {IWeth} from '@interfaces/external/IWeth.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';

abstract contract ProxyUser is BaseUser, Contracts, ScriptBase {
  mapping(address => HaiProxy) proxy;
  mapping(address => mapping(bytes32 => uint256)) safe;
  mapping(address => mapping(bytes32 => address)) safeHandler;

  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal virtual override returns (uint256 _generatedDebt, uint256 _lockedCollateral) {
    (uint256 _safeId,) = _getSafe(_user, _cType);
    address _safeHandler = safeManager.safeData(_safeId).safeHandler;

    ISAFEEngine.SAFE memory _safe = safeEngine.safes(_cType, _safeHandler);
    _generatedDebt = _safe.generatedDebt;
    _lockedCollateral = _safe.lockedCollateral;
  }

  function _lockETH(address _user, uint256 _collatAmount) internal virtual override {
    vm.startPrank(_user);
    HaiProxy _proxy = _getProxy(_user);
    (uint256 _safeId,) = _getSafe(_user, ETH_A);

    IWeth(address(collateral[ETH_A])).deposit{value: _collatAmount}();
    collateral[ETH_A].approve(address(_proxy), _collatAmount);

    // bytes memory _callData = abi.encodeWithSelector(
    //   BasicActions.lockTokenCollateral.selector,
    //   address(safeManager),
    //   address(collateralJoin[ETH_A]),
    //   _safeId,
    //   _collatAmount,
    //   true
    // );

    // _proxy.execute(address(proxyActions), _callData);

    vm.stopPrank();
  }

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal virtual override {
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    IERC20Metadata _collateral = ICollateralJoin(_collateralJoin).collateral();

    ERC20ForTest(address(_collateral)).mint(_user, _amount);

    _collateral.approve(address(_proxy), _amount);
    // ICollateralJoin(_collateralJoin).join(_user, _amount);
    vm.stopPrank();
  }

  function _joinCoins(address _user, uint256 _amount) internal virtual override {
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    systemCoin.approve(address(_proxy), _amount);

    bytes memory _callData =
      abi.encodeWithSelector(CommonActions.coinJoin_join.selector, address(coinJoin), _user, _amount);
    _proxy.execute(address(proxyActions), _callData);

    vm.stopPrank();
  }

  function _exitCoin(address _user, uint256 _amount) internal virtual override {
    // proxy implementation already exits coins
  }

  function _liquidateSAFE(bytes32 _cType, address _user) internal virtual override {
    (, address _safeHandler) = _getSafe(_user, _cType);
    liquidationEngine.liquidateSAFE(_cType, _safeHandler);
  }

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _collatAmount,
    int256 _deltaDebt
  ) internal virtual override {
    HaiProxy _proxy = _getProxy(_user);
    bytes32 _cType = ICollateralJoin(_collateralJoin).collateralType();
    (uint256 _safeId,) = _getSafe(_user, _cType);

    if (_cType == ETH_A) _lockETH(_user, uint256(_collatAmount));
    else _joinTKN(_user, _collateralJoin, uint256(_collatAmount));

    vm.startPrank(_user);

    bytes memory _callData = abi.encodeWithSelector(
      BasicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaDebt, // wad
      true
    );

    _proxy.execute(address(proxyActions), _callData);
    vm.stopPrank();
  }

  function _getProxy(address _user) internal returns (HaiProxy) {
    if (proxy[_user] == HaiProxy(address(0))) {
      proxy[_user] = HaiProxy(proxyRegistry.build());
    }
    return proxy[_user];
  }

  function _getSafe(address _user, bytes32 _collateralType) internal returns (uint256 _safeId, address _safeHandler) {
    HaiProxy _proxy = _getProxy(_user);

    if (safe[_user][_collateralType] == 0) {
      bytes memory _callData =
        abi.encodeWithSelector(BasicActions.openSAFE.selector, address(safeManager), _collateralType, address(_proxy));

      (bytes memory _response) = _proxy.execute(address(proxyActions), _callData);
      _safeId = abi.decode(_response, (uint256));
      _safeHandler = safeManager.safeData(_safeId).safeHandler;

      // store safeId and safeHandler in local storage
      safe[_user][_collateralType] = _safeId;
      safeHandler[_user][_collateralType] = _safeHandler;
    }

    return (safe[_user][_collateralType], safeHandler[_user][_collateralType]);
  }

  function _buyCollateral(
    address _user,
    address _collateral,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _amountToBid
  ) internal override {
    _joinCoins(_user, _amountToBid);
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    safeEngine.transferInternalCoins(address(_user), address(_proxy), _amountToBid * 1e27);

    // TODO: abstract in proxies/ directory
    BuyCollateral _proxyAction = new BuyCollateral();
    bytes memory _callData = abi.encodeWithSelector(
      BuyCollateral.buyCollateral.selector,
      safeEngine,
      systemCoin,
      _collateral,
      _collateralAuctionHouse,
      _auctionId,
      _amountToBid
    );

    _proxy.execute(address(_proxyAction), _callData);
    vm.stopPrank();
  }

  function _buyProtocolToken(
    address _user,
    uint256 _auctionId,
    uint256 _amountToBuy,
    uint256 _amountToBid
  ) internal override {
    // TODO: standarize with _buyCollateral (either join in test or in action)
    HaiProxy _proxy = _getProxy(_user);

    vm.startPrank(_user);
    safeEngine.transferInternalCoins(address(_user), address(_proxy), _amountToBid); // TODO: why not 1e27?

    BuyProtocolToken _proxyAction = new BuyProtocolToken();
    bytes memory _callData = abi.encodeWithSelector(
      BuyProtocolToken.buyProtocolToken.selector,
      safeEngine,
      protocolToken,
      debtAuctionHouse,
      _auctionId,
      _amountToBuy,
      _amountToBid
    );

    _proxy.execute(address(_proxyAction), _callData);
    vm.stopPrank();
  }

  function _settleDebtAuction(address _user, uint256 _auctionId) internal override {
    HaiProxy _proxy = _getProxy(_user);
    vm.startPrank(_user);
    BuyProtocolToken _proxyAction = new BuyProtocolToken();
    bytes memory _callData =
      abi.encodeWithSelector(BuyProtocolToken.settleAuction.selector, protocolToken, debtAuctionHouse, _auctionId);

    _proxy.execute(address(_proxyAction), _callData);
    vm.stopPrank();
  }

  function _buySystemCoin(address _user, uint256 _auctionId, uint256 _amountToBid) internal override {}
}

/**
 * @notice This is what the proxy contract executes in batch
 * @dev    To be abstracted and improved in `proxies/` directory
 */
contract BuyCollateral {
  function buyCollateral(
    address _safeEngine,
    address _systemCoin,
    address _collateral,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _amountToBid
  ) external {
    ISAFEEngine(_safeEngine).approveSAFEModification(_collateralAuctionHouse);
    IERC20Metadata(_systemCoin).approve(_collateralAuctionHouse, _amountToBid);
    ICollateralAuctionHouse(_collateralAuctionHouse).buyCollateral(_auctionId, _amountToBid);
    // TODO: handle better
    IERC20Metadata(_collateral).transfer(msg.sender, IERC20Metadata(_collateral).balanceOf(address(this)));
  }
}

contract BuyProtocolToken {
  function buyProtocolToken(
    address _safeEngine,
    address _protocolToken,
    address _debtAuctionHouse,
    uint256 _auctionId,
    uint256 _amountToBuy,
    uint256 _amountToBid
  ) external {
    ISAFEEngine(_safeEngine).approveSAFEModification(_debtAuctionHouse);
    IDebtAuctionHouse(_debtAuctionHouse).decreaseSoldAmount(_auctionId, _amountToBuy, _amountToBid);
  }

  function settleAuction(address _protocolToken, address _debtAuctionHouse, uint256 _auctionId) external {
    IDebtAuctionHouse(_debtAuctionHouse).settleAuction(_auctionId);
    IERC20Metadata(_protocolToken).transfer(msg.sender, IERC20Metadata(_protocolToken).balanceOf(address(this)));
  }
}
