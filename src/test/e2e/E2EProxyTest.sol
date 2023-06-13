// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralJoin, ISAFEEngine} from '@script/Contracts.s.sol';
import {ETH_A} from '@script/Params.s.sol';

import {IWeth} from '@interfaces/external/IWeth.sol';
import {E2ETest} from '@test/e2e/E2ETest.t.sol';

import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';

contract E2EProxyTest is E2ETest {
  mapping(address => HaiProxy) proxy;
  mapping(address => mapping(bytes32 => uint256)) safe;

  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal virtual override returns (uint256 _generatedDebt, uint256 _lockedCollateral) {
    uint256 _safeId = _getSafe(_user, ETH_A);
    address _safeHandler = safeManager.safeData(_safeId).safeHandler;

    ISAFEEngine.SAFE memory _safe = safeEngine.safes(_cType, _safeHandler);
    _generatedDebt = _safe.generatedDebt;
    _lockedCollateral = _safe.lockedCollateral;
  }

  function _lockETH(address _user, uint256 _collatAmount) internal virtual override {
    vm.startPrank(_user);
    HaiProxy _proxy = _getProxy(_user);
    uint256 _safe = _getSafe(_user, ETH_A);

    IWeth(address(collateral[ETH_A])).deposit{value: _collatAmount}();
    collateral[ETH_A].approve(address(_proxy), _collatAmount);

    // bytes memory _callData = abi.encodeWithSelector(
    //   BasicActions.lockTokenCollateral.selector,
    //   address(safeManager),
    //   address(collateralJoin[ETH_A]),
    //   _safe,
    //   _collatAmount,
    //   true
    // );

    // _proxy.execute(address(proxyActions), _callData);

    vm.stopPrank();
  }

  function _liquidateSAFE(bytes32 _cType, address _user) internal virtual override {
    uint256 _safe = _getSafe(_user, _cType);
    liquidationEngine.liquidateSAFE(_cType, safeManager.safeData(_safe).safeHandler);
  }

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _collatAmount,
    int256 _deltaDebt
  ) internal virtual override {
    HaiProxy _proxy = _getProxy(_user);
    bytes32 _cType = ICollateralJoin(_collateralJoin).collateralType();
    uint256 _safe = _getSafe(_user, _cType);

    if (_cType == ETH_A) _lockETH(_user, uint256(_collatAmount));
    else _joinTKN(_user, ICollateralJoin(_collateralJoin), uint256(_collatAmount));

    vm.startPrank(_user);

    bytes memory _callData = abi.encodeWithSelector(
      BasicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[ETH_A]),
      address(coinJoin),
      _safe,
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

  function _getSafe(address _user, bytes32 _collateralType) internal returns (uint256 _safe) {
    HaiProxy _proxy = _getProxy(_user);

    if (safe[_user][_collateralType] == 0) {
      bytes memory _callData =
        abi.encodeWithSelector(BasicActions.openSAFE.selector, address(safeManager), _collateralType, address(_proxy));

      (bytes memory _response) = _proxy.execute(address(proxyActions), _callData);
      safe[_user][_collateralType] = abi.decode(_response, (uint256));
    }

    return safe[_user][_collateralType];
  }
}
