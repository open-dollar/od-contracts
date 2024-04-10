// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

// Mock for testing ODProxy -> CommonActions
contract CommonActionsMock {
  address public coinJoin;
  address public dst;
  address public src;
  uint256 public wad;
  address public collateralJoin;

  function joinSystemCoins(address _coinJoin, address _dst, uint256 _wad) external {
    coinJoin = _coinJoin;
    dst = _dst;
    wad = _wad;
  }

  function exitSystemCoins(address _coinJoin, address _src, uint256 _wad) external {
    coinJoin = _coinJoin;
    src = _src;
    wad = _wad;
  }

  function exitAllSystemCoins(address _coinJoin) external {
    coinJoin = _coinJoin;
  }

  function exitCollateral(address _collateralJoin, uint256 _wad) external {
    collateralJoin = _collateralJoin;
    wad = _wad;
  }
}

contract CommonActionsTest is ActionBaseTest {
  CommonActionsMock commonActions;

  function setUp() public {
    proxy = new ODProxy(alice);
    commonActions = new CommonActionsMock();
  }

  function test_joinSystemCoins() public {
    address target = address(commonActions);
    address _coinJoin = address(0x1);
    address _dst = address(0x2);
    uint256 _wad = 100;
    vm.startPrank(alice);

    proxy.execute(
      address(commonActions), abi.encodeWithSignature('joinSystemCoins(address,address,uint256)', _coinJoin, _dst, _wad)
    );

    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    address savedDataDst = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('dst()')));
    uint256 savedDataWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('wad()')));

    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataDst, _dst);
    assertEq(savedDataWad, _wad);
  }

  function test_exitSystemCoins() public {
    address target = address(commonActions);
    address _coinJoin = address(0x1);
    address _src = address(0x2);
    uint256 _wad = 100;
    vm.startPrank(alice);

    proxy.execute(
      address(commonActions), abi.encodeWithSignature('exitSystemCoins(address,address,uint256)', _coinJoin, _src, _wad)
    );

    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    address savedDataSrc = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('src()')));
    uint256 savedDataWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('wad()')));

    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSrc, _src);
    assertEq(savedDataWad, _wad);
  }

  function test_exitAllSystemCoins() public {
    address target = address(commonActions);
    address _coinJoin = address(0x1);
    uint256 _wad = 100;
    vm.startPrank(alice);

    proxy.execute(address(commonActions), abi.encodeWithSignature('exitAllSystemCoins(address)', _coinJoin));

    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));

    assertEq(savedDataCoinJoin, _coinJoin);
  }

  function test_exitCollateral() public {
    address target = address(commonActions);
    address _collateralJoin = address(0x1);
    uint256 _wad = 100;
    vm.startPrank(alice);

    proxy.execute(
      address(commonActions), abi.encodeWithSignature('exitCollateral(address,uint256)', _collateralJoin, _wad)
    );

    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    uint256 savedDataWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('wad()')));

    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataWad, _wad);
  }
}
