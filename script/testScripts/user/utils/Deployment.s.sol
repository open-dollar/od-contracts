// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import 'forge-std/Script.sol';
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";

import '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

import {SepoliaContracts} from '@script/SepoliaContracts.s.sol';
import {SepoliaContracts} from '@script/SepoliaContracts.s.sol';

import {Contracts} from '@script/Contracts.s.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';
import {MintableVoteERC20} from '@contracts/for-test/MintableVoteERC20.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
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

contract Deployment is Contracts, SepoliaContracts, Script {
  // Wad
  uint256 public constant WAD = 1 ether;
  uint256 public constant ZERO_DEBT = 0;

  // Collateral
  bytes32 public constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
  bytes32 public constant WSTETH = bytes32('WSTETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
  bytes32 public constant ARB = bytes32('ARB');

  IERC20 public WETH_TOKEN = IERC20(MintableERC20_WSTETH_Address);

  // User wallet address
  address public USER1 = vm.envAddress('ARB_SEPOLIA_PUBLIC1');
  address public USER2 = vm.envAddress('ARB_SEPOLIA_PUBLIC2');

  // Safe id
  uint256 public SAFE = vm.envUint('SAFE');

  // Collateral and debt
  uint256 public COLLATERAL = vm.envUint('COLLATERAL'); // ex: COLLATERAL=400000000000000000 (0.4 ether)
  uint256 public DEBT = vm.envUint('DEBT'); // ex: DEBT=200000000000000000000 (200 ether)

  function setUp() public {
    safeManager = ODSafeManager(ODSafeManager_Address);
    vault721 = Vault721(Vault721_Address);
    basicActions = BasicActions(BasicActions_Address);
    debtBidActions = DebtBidActions(DebtBidActions_Address);
    surplusBidActions = SurplusBidActions(SurplusBidActions_Address);
    collateralBidActions = CollateralBidActions(CollateralBidActions_Address);
    rewardedActions = RewardedActions(RewardedActions_Address);
    safeEngine = SAFEEngine(SAFEEngine_Address);

    protocolToken = ProtocolToken(SEPOLIA_PROTOCOL_TOKEN); // OPEN
    systemCoin = SystemCoin(SEPOLIA_SYSTEM_COIN); // OD

    taxCollector = TaxCollector(TaxCollector_Address);
    coinJoin = CoinJoin(CoinJoin_Address);
    collateralJoin[WSTETH] =
      CollateralJoin(CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address);
  }
}
