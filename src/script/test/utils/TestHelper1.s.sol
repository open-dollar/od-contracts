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
 * @dev to avoid msg.sender context of forge's DefaultSender, fill in USER with desired wallet/EOA
 */
contract TestHelperScript1 is TestContracts, Script {
  // Wad
  uint256 public constant WAD = 1e16;

  // Collateral
  bytes32 public constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
  bytes32 public constant WETH = bytes32('WETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
  bytes32 public constant OP = bytes32('OP'); // 0x4f50000000000000000000000000000000000000000000000000000000000000

  IERC20 public constant wEthToken = IERC20(0x4200000000000000000000000000000000000006);

  // User wallet address
  address public constant USER1 = 0x23aD35FAab005a5E69615d275176e5C22b2ceb9E;
  address public constant USER2 = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;

  function setUp() public {
    proxyFactory = HaiProxyFactory(0x7cE9283e10543F7792AA9dFABC66A61C87ecC6F2);
    proxyRegistry = HaiProxyRegistry(0xCEC3AfFac05522c21B59e62CF98122aD47168B9d);
    safeManager = HaiSafeManager(0x1575B37E8bacE8d07594314537109A59658DAD22);
    basicActions = BasicActions(0x44Be9d8e63F0746413eAFaf9379fE91982EC8801);
    debtBidActions = DebtBidActions(0x2c1d3156725388820c6b9aA4CC0d33f38e268C67);
    surplusBidActions = SurplusBidActions(0xd976B790B5440a493EbE310852f193437D01796E);
    collateralBidActions = CollateralBidActions(0x73991C3a4CA35b0373C163321Cac9C31Ed4bf0ae);
    // rewardedActions = RewardedActions(0x2Ec6a44AA9dBCd62886498D4B67887AF50563098);

    protocolToken = ProtocolToken(0xe305D09d46bD6c9C0178799Bc1424282b798876C); // OPEN
    systemCoin = SystemCoin(0xD0fbafe59e8af03C81b48ADbd3c3679E5D7Fa613); // HAI

    taxCollector = TaxCollector(0x14e604A11a6AF9495F08f8647053467AeBdd226e);
    coinJoin = CoinJoin(0xAa6bC900E76C76D61875765Be902Db0b4beA4B4D);
    collateralJoin[WETH] = CollateralJoin(0xc98B42c0008Ea860c17f5C374BA782130b333DF5);
  }

  /**
   * @dev this function calls the proxyFactory via ProxyRegistry,
   * and it will only allow 1 proxy per wallet/EOA.
   * use the `deployProxy` script to bypass the ProxyRegistry
   */
  function deployOrFind(address owner) public returns (address payable) {
    HaiProxy proxy = proxyRegistry.proxies(owner);
    if (proxy == HaiProxy(payable(address(0))) || proxy.owner() != owner) {
      return proxyRegistry.build(owner);
    } else {
      return payable(address(proxy));
    }
  }
}
