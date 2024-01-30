// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import 'forge-std/console2.sol';

// BROADCAST
// source .env && forge script RepayAllDebtAndFreeTokenCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RepayAllDebtAndFreeTokenCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract RepayAllDebtAndFreeTokenCollateral is TestScripts {
  /// @dev this script will pay off as much debt as it can with your availible COIN and then unlock as much Collateral as possible.
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER1));

    systemCoin.approve(proxy, type(uint256).max);

    repayAllDebtAndFreeTokenCollateral(WSTETH, SAFE, proxy);
    vm.stopBroadcast();
  }
}


// source .env && forge script DeployBasicActions --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
contract DeployBasicActions is TestScripts {
  address _basicActions;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    _basicActions = address(new BasicActions());
    vm.stopBroadcast();
    console2.log('NEW BASIC ACTIONS: ', _basicActions);
  }
}

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
//source .env && forge script CheckBalances --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
contract CheckBalances is TestScripts {
    uint256 public systemCoinBalance;
    uint256 public collateralBalance;
    function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address user1 = vm.envAddress('ARB_SEPOLIA_PUBLIC1');
    systemCoinBalance = systemCoin.balanceOf(user1);
    collateralBalance = IERC20(MintableERC20_WSTETH_Address).balanceOf(user1);
    vm.stopBroadcast();
    console2.log('COIN Balance: ', systemCoinBalance / 1e18);
    console2.log('Collateral Balance', collateralBalance / 1e18);
  }
}
// BROADCAST
// source .env && forge script AllowSAFE --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

contract AllowSAFE is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER1));

    allowSAFE(proxy, SAFE, true, proxy);
    vm.stopBroadcast();
}
}

contract GetSafeData is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER1));

    IODSafeManager.SAFEData memory _safeData = safeData(SAFE);
      console2.log('OWNER: ', _safeData.owner);
      console2.log('SafeHandler: ', _safeData.safeHandler);
    vm.stopBroadcast();
}}