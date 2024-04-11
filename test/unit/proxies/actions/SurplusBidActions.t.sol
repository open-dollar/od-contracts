// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';
import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

contract SafeEngineMock {
  bool public wasApproveSAFEModificationCalled;

  bool public canModifySAF;
  ISAFEEngine.SAFE public safe;
  uint256 public collateralBalance;
  uint256 public coinBalancePoint;

  function reset() external {
    wasApproveSAFEModificationCalled = false;
    canModifySAF = false;
    safe = ISAFEEngine.SAFE(0, 0);
    collateralBalance = 0;
  }

  function _mock_setCollateralBalance(uint256 _collateralBalance) external {
    collateralBalance = _collateralBalance;
  }

  function _mock_addSafeData(uint256 lockedCollateral, uint256 generatedDebt) external {
    safe = ISAFEEngine.SAFE(lockedCollateral, generatedDebt);
  }

  function mock_setCanModifySAFE(bool _canModifySAFE) external {
    canModifySAF = _canModifySAFE;
  }

  function mock_setCoinBalance(uint256 _coinBalance) external {
    coinBalancePoint = _coinBalance;
  }

  function canModifySAFE(address _safe, address _account) external view returns (bool _allowed) {
    return canModifySAF;
  }

  function approveSAFEModification(address _account) external {
    wasApproveSAFEModificationCalled = true;
  }

  function tokenCollateral(bytes32 _cType, address _account) external view returns (uint256 _collateralBalance) {
    return collateralBalance;
  }

  function safes(bytes32 _cType, address _safeAddress) external view returns (ISAFEEngine.SAFE memory _safeData) {
    return safe;
  }

  function coinBalance(address _account) external view returns (uint256 _coinBalance) {
    return coinBalancePoint;
  }
}

contract CoinJoinMock {
  address public safeEngine;
  bool public wasExitCalled;

  constructor() {
    safeEngine = address(new SafeEngineMock());
  }

  function reset() external {
    wasExitCalled = false;
    SafeEngineMock(safeEngine).reset();
  }

  function exit(address _account, uint256 _wad) external {
    wasExitCalled = true;
  }
}

contract SurplusActionsHouseMock {
  address public highBidder;
  ProtocolToken public protocolTokenContract;
  address public protocolToken;

  bool public wasSettleAuctionCalled;
  bool public wasIncreaseBidSizeCalled;

  constructor() {
    protocolTokenContract = new ProtocolToken();
    protocolTokenContract.initialize('Protocol Token', 'PT');
    protocolTokenContract.mint(address(this), 1000 ether);
    protocolTokenContract.mint(address(0x1), 1000 ether);
    protocolToken = address(protocolTokenContract);
  }

  function reset() external {
    highBidder = address(0);
    wasIncreaseBidSizeCalled = false;
    wasSettleAuctionCalled = false;
  }

  function setHighBidder(address _highBidder) external {
    highBidder = _highBidder;
  }

  function auctions(uint256 _id) external view returns (ICommonSurplusAuctionHouse.Auction memory _auction) {
    return ICommonSurplusAuctionHouse.Auction({
      bidAmount: 100,
      amountToSell: 100,
      highBidder: highBidder == address(0) ? address(0x1) : highBidder,
      bidExpiry: 100,
      auctionDeadline: 100
    });
  }

  function increaseBidSize(uint256 _auctionId, uint256 _bidAmount) external {
    wasIncreaseBidSizeCalled = true;
  }

  function settleAuction(uint256 _auctionId) external {
    wasSettleAuctionCalled = true;
  }
}

// Testing the calls from ODProxy to SurplusBidActions.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract SurplusBidActionTest is ActionBaseTest {
  SurplusBidActions surplusBidActions = new SurplusBidActions();
  SurplusActionsHouseMock surplusActionsHouseMock = new SurplusActionsHouseMock();
  CoinJoinMock coinJoin = new CoinJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_increaseBidSize() public {
    surplusActionsHouseMock.reset();
    address _surplusAuctionHouse = address(surplusActionsHouseMock);
    uint256 _auctionId = 1;
    uint256 _bidAmount = 100;
    vm.startPrank(alice);
    // add proxy as high bidder
    surplusActionsHouseMock.setHighBidder(address(proxy));
    // approve protocol token spending
    surplusActionsHouseMock.protocolTokenContract().approve(address(proxy), 10 ether);
    proxy.execute(
      address(surplusActionsHouseMock.protocolTokenContract()),
      abi.encodeWithSignature('approve(address,uint256)', _surplusAuctionHouse, 10 ether)
    );

    proxy.execute(
      address(surplusBidActions),
      abi.encodeWithSignature('increaseBidSize(address,uint256,uint256)', _surplusAuctionHouse, _auctionId, _bidAmount)
    );

    assertEq(surplusActionsHouseMock.wasIncreaseBidSizeCalled(), true);
    assertEq(surplusActionsHouseMock.wasSettleAuctionCalled(), false);
  }

  function test_settleAuctionWithSafeModificationTrue() public {
    surplusActionsHouseMock.reset();
    coinJoin.reset();
    address _coinJoin = address(coinJoin);
    address _surplusAuctionHouse = address(surplusActionsHouseMock);
    uint256 _auctionId = 1;
    vm.startPrank(alice);
    SafeEngineMock safeEngine = SafeEngineMock(coinJoin.safeEngine());
    safeEngine.mock_setCanModifySAFE(true);
    proxy.execute(
      address(surplusBidActions),
      abi.encodeWithSignature('settleAuction(address,address,uint256)', _coinJoin, _surplusAuctionHouse, _auctionId)
    );

    assertEq(surplusActionsHouseMock.wasIncreaseBidSizeCalled(), false);
    assertEq(surplusActionsHouseMock.wasSettleAuctionCalled(), true);
    assertEq(coinJoin.wasExitCalled(), true);
    assertEq(safeEngine.wasApproveSAFEModificationCalled(), false);
  }

  function test_settleAuctionWithSafeModificationFalse() public {
    address _coinJoin = address(coinJoin);
    address _surplusAuctionHouse = address(surplusActionsHouseMock);
    uint256 _auctionId = 1;
    vm.startPrank(alice);
    SafeEngineMock safeEngine = SafeEngineMock(coinJoin.safeEngine());
    safeEngine.mock_setCanModifySAFE(false);
    proxy.execute(
      address(surplusBidActions),
      abi.encodeWithSignature('settleAuction(address,address,uint256)', _coinJoin, _surplusAuctionHouse, _auctionId)
    );

    assertEq(surplusActionsHouseMock.wasIncreaseBidSizeCalled(), false);
    assertEq(surplusActionsHouseMock.wasSettleAuctionCalled(), true);
    assertEq(coinJoin.wasExitCalled(), true);
    assertEq(safeEngine.wasApproveSAFEModificationCalled(), true);
  }
}
