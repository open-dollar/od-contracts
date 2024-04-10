// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';

// Mock for testing ODProxy -> CollateralBidActions
contract CollateralBidActionsMock {
  address public coinJoin;
  address public collateralJoin;
  address public collateralAuctionHouse;
  uint256 public auctionId;
  uint256 public minCollateralAmount;
  uint256 public bidAmount;

  function buyCollateral(
    address _coinJoin,
    address _collateralJoin,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _minCollateralAmount,
    uint256 _bidAmount
  ) external {
    coinJoin = _coinJoin;
    collateralJoin = _collateralJoin;
    collateralAuctionHouse = _collateralAuctionHouse;
    auctionId = _auctionId;
    minCollateralAmount = _minCollateralAmount;
    bidAmount = _bidAmount;
  }
}

contract CollateralBidActionsTest is ActionBaseTest {
  CollateralBidActionsMock collateralBidActions;

  function setUp() public {
    proxy = new ODProxy(alice);
    collateralBidActions = new CollateralBidActionsMock();
  }

  function test_buyCollateral() public {
    address target = address(collateralBidActions);
    address _coinJoin = address(0x1);
    address _collateralJoin = address(0x2);
    address _collateralAuctionHouse = address(0x3);
    uint256 _auctionId = 1;
    uint256 _minCollateralAmount = 100;
    uint256 _bidAmount = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(collateralBidActions),
      abi.encodeWithSignature(
        'buyCollateral(address,address,address,uint256,uint256,uint256)',
        _coinJoin,
        _collateralJoin,
        _collateralAuctionHouse,
        _auctionId,
        _minCollateralAmount,
        _bidAmount
      )
    );

    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    address savedDataCollateralAuctionHouse =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralAuctionHouse()')));
    uint256 savedDataAuctionId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('auctionId()')));
    uint256 savedDataMinCollateralAmount =
      decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('minCollateralAmount()')));
    uint256 savedDataBidAmount = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('bidAmount()')));

    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataCollateralAuctionHouse, _collateralAuctionHouse);
    assertEq(savedDataAuctionId, _auctionId);
    assertEq(savedDataMinCollateralAmount, _minCollateralAmount);
    assertEq(savedDataBidAmount, _bidAmount);
  }
}
