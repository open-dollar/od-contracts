// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import 'forge-std/Script.sol';

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {TestContracts} from '@script/test/utils/TestContracts.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {HaiProxyFactory} from '@contracts/proxies/HaiProxyFactory.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';
import {HaiSafeManager} from '@contracts/proxies/HaiSafeManager.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {CollateralBidActions} from '@contracts/proxies/actions/CollateralBidActions.sol';
import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';
import {DebtBidActions} from '@contracts/proxies/actions/DebtBidActions.sol';
import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';
// import {RewardedActions} from '@contracts/proxies/actions/RewardedActions.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';

/**
 * @dev Deployment2 refers to HAI contracts
 */
contract Deployment is TestContracts, Script {
  // Wad
  uint256 public constant WAD = 1 ether;

  // Collateral
  bytes32 public constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
  bytes32 public constant WETH = bytes32('WETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
  bytes32 public constant OP = bytes32('OP'); // 0x4f50000000000000000000000000000000000000000000000000000000000000

  IERC20 public constant WETH_TOKEN = IERC20(0x4200000000000000000000000000000000000006);

  // User wallet address
  address public constant USER1 = 0x23aD35FAab005a5E69615d275176e5C22b2ceb9E;
  address public constant USER2 = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;

  function setUp() public {
    proxyFactory = HaiProxyFactory(0xCA969d78b986dE02CC6E44194e99C0b2F77F3cEc);
    proxyRegistry = HaiProxyRegistry(0x8FF12e19f1f246D0257D478C90eB47a960F4DBb4);
    safeManager = HaiSafeManager(0xc0C6e2e5a31896e888eBEF5837Bb70CB3c37D86C);
    basicActions = BasicActions(0x0c3287b5C1Ea5b04E90A3d1af02B78544b33f573);
    debtBidActions = DebtBidActions(0xFb47e938010Cbd6f6b5953Be7aDc10F9c07d5CAA);
    surplusBidActions = SurplusBidActions(0xd7d804b859B2C23B310db2510316426D99976ff6);
    collateralBidActions = CollateralBidActions(0x85f9a28F7F7e343e1806E112272bd783eA73b4B9);
    // rewardedActions = RewardedActions(0xdD481aF67e8dfee190545Ae1b97c36373BfA1a7e);

    protocolToken = ProtocolToken(0xbcc847DdE48E579fa8d98E0d4bd46161A0f84F8A); // OPEN
    systemCoin = SystemCoin(0x8548Dd38Fd5f54173cf349E99379C1FEC945b469); // HAI

    taxCollector = TaxCollector(0x18059871eA044bFE1e92F5EF0D5D6e621160C94d);
    coinJoin = CoinJoin(0xfc63F2CfbfB09131a87452dF713E84885fFF9466);
    collateralJoin[WETH] = CollateralJoin(0xFb0758b07B4260958Cb1589091489E2A2d9af513);
  }
}
