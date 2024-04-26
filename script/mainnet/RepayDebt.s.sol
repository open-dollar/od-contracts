// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@script/Registry.s.sol';

import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {WSTETH, ARB, RETH} from '@script/MainnetParams.s.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';

// BROADCAST
// source .env && forge script RepayDebtMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RepayDebtMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract RepayDebtMainnet is MainnetDeployment, Script, Test {
  address internal constant _USER = 0x9492510BbCB93B6992d8b7Bb67888558E12DCac4;
  uint256 internal _userPk;
  address internal _user;
  bool internal _broadcast;
  address internal _newBasicActions;

  modifier prankSwitch(address _caller, address _account) {
    if (_caller == _account) _broadcast = true;
    if (_broadcast) {
      vm.startBroadcast(_userPk);
    } else {
      vm.startPrank(_account);
      _user = _account;
    }
    _;
    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }

  function setUp() public {
    _userPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    _user = vm.addr(_userPk);
  }
  /// @dev this script will pay off as much debt as it can with your availible COIN and then unlock as much Collateral as possible.

  function deployOrFind(address owner) public returns (address payable) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return vault721.build(owner);
    } else {
      return payable(address(proxy));
    }
  }

  /**
   * @dev will repays all debt with user's COIN balance and unlocks all collateral
   */
  function repayAllDebtAndFreeTokenCollateral(
    bytes32 _cType,
    uint256 _safeId,
    address _proxy,
    uint256 _collateralWad
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.repayAllDebtAndFreeTokenCollateral.selector,
      address(safeManager),
      collateralJoin[_cType],
      address(coinJoin),
      _safeId,
      _collateralWad
    );
    ODProxy(_proxy).execute(address(_newBasicActions), payload);
  }

  // /**
  //  * @dev repays all of debt with user's COIN BALANCE
  //  */
  function repayAllDebt(uint256 _safeId, address _proxy) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.repayAllDebt.selector, address(safeManager), address(coinJoin), _safeId);
    ODProxy(_proxy).execute(address(_newBasicActions), payload);
  }

  function run() public prankSwitch(_user, _USER) {
    address proxy = address(deployOrFind(_user));

    _newBasicActions = address(new BasicActions());

    systemCoin.approve(proxy, type(uint256).max);
    uint256 safeId = 24;
    uint256 collateralWad = 1;

    repayAllDebt(safeId, proxy);
    // repayAllDebtAndFreeTokenCollateral(RETH, safeId, proxy, collateralWad);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}
