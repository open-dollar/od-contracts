// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import 'forge-std/Script.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {ARB_GOERLI_WETH} from '@script/Registry.s.sol';

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {TestContracts} from '@script/test/utils/TestContracts.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {CollateralBidActions} from '@contracts/proxies/actions/CollateralBidActions.sol';
import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';
import {DebtBidActions} from '@contracts/proxies/actions/DebtBidActions.sol';
import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';
import {RewardedActions} from '@contracts/proxies/actions/RewardedActions.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {PostSettlementSurplusBidActions} from '@contracts/proxies/actions/PostSettlementSurplusBidActions.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';

/**
 * @dev Deployment2 refers to HAI contracts
 */
contract Deployment is TestContracts, GoerliContracts, Script {
  // Wad
  uint256 public constant WAD = 1 ether;

  // Collateral
  bytes32 public constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
  bytes32 public constant WETH = bytes32('WETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
  bytes32 public constant FTRG = bytes32('FTRG');

  IERC20 public constant WETH_TOKEN = IERC20(ARB_GOERLI_WETH);

  // User wallet address
  address public constant USER1 = 0x23aD35FAab005a5E69615d275176e5C22b2ceb9E;
  address public constant USER2 = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;

  function setUp() public {
    safeManager = ODSafeManager(odSafeManagerAddr);
    vault721 = Vault721(vault721Addr);
    basicActions = BasicActions(basicActionsAddr);
    debtBidActions = DebtBidActions(debtBidActionsAddr);
    surplusBidActions = SurplusBidActions(surplusBidActionsAddr);
    collateralBidActions = CollateralBidActions(collateralBidActionsAddr);
    rewardedActions = RewardedActions(rewardedActionsAddr);

    protocolToken = ProtocolToken(protocolTokenAddr); // OPEN
    systemCoin = SystemCoin(systemCoinAddr); // HAI

    taxCollector = TaxCollector(taxCollectorAddr);
    coinJoin = CoinJoin(coinJoinAddr);
    collateralJoin[WETH] = CollateralJoin(collateralJoinChild_WETHAddr);
  }
}
