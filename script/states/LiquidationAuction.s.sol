// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/console.sol";
import {DebtState} from "./DebtState.s.sol";
import {ODSafeManager} from "@contracts/proxies/ODSafeManager.sol";
import {ODProxy} from "@contracts/proxies/ODProxy.sol";
import {ILiquidationEngine} from "@interfaces/ILiquidationEngine.sol";

contract LiquidationAuction is DebtState {

    mapping (bytes32 _cType => uint256 _auctionId) public auctionIds;

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

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

          console.logBytes4(ILiquidationEngine.LiqEng_SAFENotUnsafe.selector);
          string memory cTypeString = bytes32ToString(cType);
          console.log(cTypeString);
          uint256 auctionId;
          auctionId = liquidationEngine.liquidateSAFE(cType, safeHandler);
          auctionIds[cType] = auctionId;
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
            systemCoin.transfer(proxy, 500_000 ether);

            for (uint256 j = 0; j < cTypes.length; j++) {
                bytes memory payloadApprove = abi.encodeWithSelector(
                systemCoin.approve.selector,
                collateralAuctionHouse[cTypes[j]],
                500_000 ether);

                bytes memory returnData = ODProxy(proxy).execute(address(systemCoin), payloadApprove);
            }
            vm.stopPrank();
        }
    }

    function run() public override {
        // call the liquidation engine
        liquidateSafes();


    }
}