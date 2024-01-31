// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/console.sol';
import {DebtState} from './DebtState.s.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';

// This script will push the collateral prices down using DebtState and then proceed to liquidate all safes
// except for the wstETH vaults. It will then bid on one collateral auction and complete it.  This is designed to
// leave many collateral auctions open for testing - but also to complete one for testing purposes.

// This script also leaves the system in a state of debt so that a debt auction can be launched

contract LiquidationAuction is DebtState {
  mapping(bytes32 _cType => uint256[] _auctionId) public auctionIds;

  // helper function for identifying the cType bytes32
  function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
    uint8 i = 0;
    while (i < 32 && _bytes32[i] != 0) {
      i++;
    }
    bytes memory bytesArray = new bytes(i);
    for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
      bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }

  // liquidate all safes except for the wstETH vaults
  function liquidateSafes() public {
    for (uint256 i = 0; i < users.length; i++) {
      address user = users[i];
      address proxy = vault721.getProxy(user);

      for (uint256 j = 0; j < cTypes.length; j++) {
        // we skip liquidating the wstETH vaults
        if (j == 1) {
          continue;
        }
        bytes32 cType = cTypes[j];
        uint256 safeId = vaultIds[proxy][cType];

        ODSafeManager.SAFEData memory safeData = safeManager.safeData(safeId);
        address safeHandler = safeData.safeHandler;

        string memory cTypeString = bytes32ToString(cType);
        console.log(cTypeString);
        uint256 auctionId;
        auctionId = liquidationEngine.liquidateSAFE(cType, safeHandler);
        auctionIds[cType].push(auctionId);
      }
    }
  }

  // transfer system coin into user proxy for all users
  // approve collateral auction house from the proxy to spend system coin
  // call buyCollateral using a delegatecall from the CollateralBidActions contract
  function transferToProxyAndApprove() public {
    for (uint256 i = 0; i < users.length; i++) {
      address user = users[i];
      address proxy = vault721.getProxy(user);
      vm.startPrank(user);
      systemCoin.approve(proxy, 500_000 ether);

      vm.stopPrank();
    }
  }

  // Use the CollateralBidActions contract to bid on the collateral auction using proxy and delegatecall
  function bidAndCompleteCollateralAuction() public {
    address user = users[0];
    bytes32 cType = cTypes[0];
    address proxy = vault721.getProxy(user);
    vm.startPrank(user);

    bytes memory payload = abi.encodeWithSelector(
      collateralBidActions.buyCollateral.selector,
      address(coinJoin),
      address(collateralJoin[cType]),
      address(collateralAuctionHouse[cType]),
      auctionIds[cType][0],
      0,
      500_000 ether
    );

    ODProxy(proxy).execute(address(collateralBidActions), payload);

    vm.stopPrank();
  }

  function addUnbackedDebtToAccountingEngine() public {
    // access the authorized accounts from the SAFEEngine
    address[] memory authorizedAccounts = safeEngine.authorizedAccounts();
    // prank an authorized accounting
    vm.prank(authorizedAccounts[0]);
    // add unbacked debt to the accounting engine by calling SAFEEngine
    safeEngine.createUnbackedDebt(address(accountingEngine), users[0], 1_000_000 * 10 ** 45);
  }

  function run() public virtual override {
    super.run();
    // call the liquidation engine
    liquidateSafes();
    transferToProxyAndApprove();
    bidAndCompleteCollateralAuction();

    uint256 coinBalance = safeEngine.coinBalance(address(accountingEngine));
    uint256 debtBalance = safeEngine.debtBalance(address(accountingEngine));

    console.log('Coin Balance of Accounting Engine');
    console.logUint(coinBalance);
    console.log('Debt Balance of Accounting Engine');
    console.logUint(debtBalance);
    addUnbackedDebtToAccountingEngine();
  }

  // forge script script/states/LiquidationAuction.s.sol:LiquidationAuction --fork-url http://localhost:8545 -vvvvv
}
