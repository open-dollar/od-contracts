// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';

// Mock for testing ODProxy -> SurplusBidActions
contract SurplusBidActionMock {
  address public surplusAuctionHouse;
  address public coinJoin;
  uint256 public auctionId;
  uint256 public bidAmount;

  function increaseBidSize(address _surplusAuctionHouse, uint256 _auctionId, uint256 _bidAmount) external {
    surplusAuctionHouse = _surplusAuctionHouse;
    auctionId = _auctionId;
    bidAmount = _bidAmount;
  }

  function settleAuction(address _coinJoin, address _surplusAuctionHouse, uint256 _auctionId) external {
    coinJoin = _coinJoin;
    surplusAuctionHouse = _surplusAuctionHouse;
    auctionId = _auctionId;
  }
}

// Testing the calls from ODProxy to SurplusBidActions.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract SurplusBidActionTest is ActionBaseTest {
  SurplusBidActionMock surplusBidAuction = new SurplusBidActionMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_increaseBidSize() public {
    address target = address(surplusBidAuction);
    address _surplusAuctionHouse = address(0x1);
    uint256 _auctionId = 1;
    uint256 _bidAmount = 100;
    vm.startPrank(alice);

    proxy.execute(
      address(surplusBidAuction),
      abi.encodeWithSignature('increaseBidSize(address,uint256,uint256)', _surplusAuctionHouse, _auctionId, _bidAmount)
    );

    address savedDataSurplusAuctionHouse =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('surplusAuctionHouse()')));
    uint256 savedDataAuctionId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('auctionId()')));
    uint256 savedDataBidAmount = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('bidAmount()')));

    assertEq(savedDataSurplusAuctionHouse, _surplusAuctionHouse);
    assertEq(savedDataAuctionId, _auctionId);
    assertEq(savedDataBidAmount, _bidAmount);
  }

  function test_settleAuction() public {
    address target = address(surplusBidAuction);
    address _coinJoin = address(0x2);
    address _surplusAuctionHouse = address(0x1);
    uint256 _auctionId = 1;
    vm.startPrank(alice);

    proxy.execute(
      address(surplusBidAuction),
      abi.encodeWithSignature('settleAuction(address,address,uint256)', _coinJoin, _surplusAuctionHouse, _auctionId)
    );

    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    address savedDataSurplusAuctionHouse =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('surplusAuctionHouse()')));
    uint256 savedDataAuctionId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('auctionId()')));

    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSurplusAuctionHouse, _surplusAuctionHouse);
    assertEq(savedDataAuctionId, _auctionId);
  }
}
