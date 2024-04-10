// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';

// Mock for testing ODProxy -> GlobalSettlementAction
contract DebtBidActionsMock {

	address public coinJoin;
	address public debtAuctionHouse;
	uint256 public auctionId;
	uint256 public soldAmount;

	function decreaseSoldAmount(
		address _coinJoin,
		address _debtAuctionHouse,
		uint256 _auctionId,
		uint256 _soldAmount
	) external {
		coinJoin = _coinJoin;
		debtAuctionHouse = _debtAuctionHouse;
		auctionId = _auctionId;
		soldAmount = _soldAmount;
	}

	function settleAuction(address _coinJoin, address _debtAuctionHouse, uint256 _auctionId) external {
		coinJoin = _coinJoin;
		debtAuctionHouse = _debtAuctionHouse;
		auctionId = _auctionId;
	}
}

// Testing the calls from ODProxy to GlobalSettlementAction.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract DebtBidActionsTest is ActionBaseTest {
	DebtBidActionsMock debtBidActionsMock;

	function setUp() public {
		proxy = new ODProxy(alice);
		debtBidActionsMock = new DebtBidActionsMock();
	}

	function test_decreaseSoldAmount() public {
		vm.startPrank(alice);
		address target = address(debtBidActionsMock);
		address coinJoin = address(0x123);
		address debtAuctionHouse = address(0x456);
		uint256 auctionId = 123;
		uint256 soldAmount = 456;

		proxy.execute(
			target,
			abi.encodeWithSignature(
				'decreaseSoldAmount(address,address,uint256,uint256)', coinJoin, debtAuctionHouse, auctionId, soldAmount
			)
		);

		address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
		address savedDataDebtAuctionHouse =
						decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('debtAuctionHouse()')));
		uint256 savedDataAuctionId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('auctionId()')));
		uint256 savedDataSoldAmount = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('soldAmount()')));

		assertEq(savedDataCoinJoin, coinJoin);
		assertEq(savedDataDebtAuctionHouse, debtAuctionHouse);
		assertEq(savedDataAuctionId, auctionId);
		assertEq(savedDataSoldAmount, soldAmount);
	}

	function test_settleAuction() public {
		vm.startPrank(alice);
		address target = address(debtBidActionsMock);
		address coinJoin = address(0x123);
		address debtAuctionHouse = address(0x456);
		uint256 auctionId = 123;

		proxy.execute(
			target, abi.encodeWithSignature('settleAuction(address,address,uint256)', coinJoin, debtAuctionHouse, auctionId)
		);

		address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
		address savedDataDebtAuctionHouse =
						decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('debtAuctionHouse()')));
		uint256 savedDataAuctionId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('auctionId()')));

		assertEq(savedDataCoinJoin, coinJoin);
		assertEq(savedDataDebtAuctionHouse, debtAuctionHouse);
		assertEq(savedDataAuctionId, auctionId);
	}
}
