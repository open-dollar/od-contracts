// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/console.sol';
import {LiquidationAuction} from './LiquidationAuction.s.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

contract DebtAuction is LiquidationAuction {
  bytes32 decreaseBidParam = 'bidDecrease';

  function decreaseBidAmount(uint256 auctionId) public {
    DebtAuctionHouse.DebtAuctionHouseParams memory params = debtAuctionHouse.params();
    uint256 decreaseAmount = params.bidDecrease;

    vm.startPrank(users[0]);
    address proxy = vault721.getProxy(users[0]);
    DebtAuctionHouse.Auction memory auction = debtAuctionHouse.auctions(auctionId);

    bytes memory payload = abi.encodeWithSelector(
      debtBidActions.decreaseSoldAmount.selector,
      address(coinJoin),
      address(debtAuctionHouse),
      auctionId,
      auction.amountToSell - decreaseAmount
    );

    systemCoin.approve(proxy, 1 ether);

    bytes memory returnData = ODProxy(proxy).execute(address(debtBidActions), payload);
  }

  function warpAndSettle(uint256 auctionId) public {
    DebtAuctionHouse.DebtAuctionHouseParams memory params = debtAuctionHouse.params();
    uint256 duration = params.bidDuration;
    vm.warp(block.timestamp + duration + 1);

    address proxy = vault721.getProxy(users[0]);
    vm.startPrank(users[0]);

    bytes memory payload = abi.encodeWithSelector(
      debtBidActions.settleAuction.selector, address(coinJoin), address(debtAuctionHouse), auctionId
    );

    bytes memory returnData = ODProxy(proxy).execute(address(debtBidActions), payload);
  }

  // This contract will queue debt via the accounting engine, start a debt auction and complete it
  function run() public override {
    super.run();

    AccountingEngine.AccountingEngineParams memory params = accountingEngine.params();
    uint256 debtRequired = params.debtAuctionBidSize;
    console.log('Unqueued debt required: ');
    console.logUint(debtRequired);
    console.log('Unqueued debt: ');
    uint256 unqueuedDebt = accountingEngine.unqueuedUnauctionedDebt();
    console.logUint(unqueuedDebt);
    console.log('Debt straight from SafeEngine: ');
    uint256 accountingEngineDebt = safeEngine.debtBalance(address(accountingEngine));
    console.logUint(accountingEngineDebt);

    // call the accounting engine to start a debt auction
    uint256 auctionId = accountingEngine.auctionDebt();

    // get the authorized accounts on the debt auction house
    address[] memory authorizedAccounts = debtAuctionHouse.authorizedAccounts();
    vm.prank(authorizedAccounts[0]);
    // change the decrease bid param to 1
    debtAuctionHouse.modifyParameters(decreaseBidParam, abi.encode(1));
    decreaseBidAmount(auctionId);
    warpAndSettle(auctionId);
  }
  // forge script script/states/DebtAuction.s.sol:DebtAuction --fork-url http://localhost:8545 -vvvvv
}
