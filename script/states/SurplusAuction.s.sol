// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SurplusState} from './SurplusState.s.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {SurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import 'forge-std/console.sol';

// This script will push the system into a state of surplus, create a surplus auction, push bids into the auction
// and then complete the auction.
contract SurplusAuction is SurplusState {
  bytes32 extraReceiverParam = 'extraSurplusReceiver';

  function setExtraSurplusReceiver() public {
    address[] memory authorizedAccounts = accountingEngine.authorizedAccounts();
    vm.prank(authorizedAccounts[0]);
    Modifiable(address(accountingEngine)).modifyParameters(extraReceiverParam, abi.encode(authorizedAccounts[0]));
  }

  function mintProtocolToken() public {
    address[] memory authorizedAccounts = protocolToken.authorizedAccounts();
    vm.prank(authorizedAccounts[0]);
    protocolToken.mint(users[0], 1000 ether);
  }

  function bidAndCompleteAuction(uint256 auctionId) public {
    vm.startPrank(users[0]);
    address proxy = vault721.getProxy(users[0]);
    protocolToken.approve(proxy, 1000 ether);

    // encode a delegate call for increaseBidSize using SurplusBidActions
    bytes memory payload = abi.encodeWithSelector(
      surplusBidActions.increaseBidSize.selector, address(surplusAuctionHouse), auctionId, 1000 ether
    );

    bytes memory returnData = ODProxy(proxy).execute(address(surplusBidActions), payload);
    SurplusAuctionHouse.Auction memory auctionData = surplusAuctionHouse.auctions(auctionId);
    uint256 auctionEnd = auctionData.bidExpiry;
    vm.warp(auctionEnd + 1);

    payload = abi.encodeWithSelector(
      surplusBidActions.settleAuction.selector, address(coinJoin), address(surplusAuctionHouse), auctionId
    );

    returnData = ODProxy(proxy).execute(address(surplusBidActions), payload);
    vm.stopPrank();
  }

  function run() public virtual override {
    super.run();
    setExtraSurplusReceiver();

    // start surplus auction
    uint256 surplusAuctionId = accountingEngine.auctionSurplus();

    mintProtocolToken();
    bidAndCompleteAuction(surplusAuctionId);
  }
  // forge script script/states/SurplusAuction.s.sol:SurplusAuction --fork-url http://localhost:8545 -vvvvv
}
