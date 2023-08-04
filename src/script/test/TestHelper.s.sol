// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import 'forge-std/Script.sol';

// Proxies
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {HaiProxyFactory} from '@contracts/proxies/HaiProxyFactory.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';
import {HaiSafeManager} from '@contracts/proxies/HaiSafeManager.sol';

// GEB Actions
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {CollateralBidActions} from '@contracts/proxies/actions/CollateralBidActions.sol';
import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';
import {DebtBidActions} from '@contracts/proxies/actions/DebtBidActions.sol';
import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';

// tokens
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';

/**
 * @dev to avoid msg.sender context of forge's DefaultSender, fill in USER with desired wallet/EOA
 */
contract TestHelperScript is Script {
  // Wad
  uint256 public constant WAD = 1e18;

  // Collateral
  bytes32 public constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
  bytes32 public constant WETH = bytes32('WETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
  bytes32 public constant OP = bytes32('OP'); // 0x4f50000000000000000000000000000000000000000000000000000000000000

  // User wallet address
  address public constant USER = 0x23aD35FAab005a5E69615d275176e5C22b2ceb9E;

  // Hai Protocol contracts
  HaiProxyFactory public constant proxyFactory = HaiProxyFactory(0x74044fDd9C267050f5b11987e1009b76b5ef806b);
  HaiProxyRegistry public constant proxyRegistry = HaiProxyRegistry(0x8505e8D84654467d032DB394637D0FaFf477568a);
  HaiSafeManager public constant safeManager = HaiSafeManager(0xE5559B4C5605a2cd4F6F3DD84D9eeF2Df7aC3EB1);
  BasicActions public constant basicActions = BasicActions(0x48fC4859e06c1096b3A02d391F96376AdA9259a8);
  DebtBidActions public constant debtBidActions = DebtBidActions(0x5fc994EBfAe4ABeFca0f2DeeFDC2C8A46AD2bEb0);
  SurplusBidActions public constant surplusBidActions = SurplusBidActions(0xB0C1470255f08a06A5123e03554Fb7CeBF41Ed6a);
  CollateralBidActions public constant collateralBidActions =
    CollateralBidActions(0xE4f9DbD083419944e401Bd709eA74fb52a8dcdCa);
  ProtocolToken public constant protocolToken = ProtocolToken(0xe305D09d46bD6c9C0178799Bc1424282b798876C); // OPEN
  SystemCoin public constant systemCoin = SystemCoin(0xD0fbafe59e8af03C81b48ADbd3c3679E5D7Fa613); // HAI

  // Hai Protocol addresses
  address public constant taxCollector = 0x979175221543b23ef11577898dA53C87779A54cE;
  address public constant coinJoin = 0x1ceABCDB63dFF8734bB9D969C398936C0d6B4ad5;

  /**
   * @dev this function calls the proxyFactory via ProxyRegistry,
   * and it will only allow 1 proxy per wallet/EOA
   */
  function findOrDeploy(address owner) public returns (address payable) {
    HaiProxy proxy = proxyRegistry.proxies(owner);
    if (proxy == HaiProxy(payable(address(0))) || proxy.owner() != owner) {
      return proxyRegistry.build(owner);
    } else {
      return payable(address(proxy));
    }
  }
}

/**
 * existing proxies to EOAs:
 * 0xD652BbC552FC71c6a68db126D10eba9720E2eC4a => 0x23aD35FAab005a5E69615d275176e5C22b2ceb9E
 * 0xC021d508AF319DD40710Bc2896882671c578036A => 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB
 */
