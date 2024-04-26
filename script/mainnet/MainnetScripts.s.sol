// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@script/Registry.s.sol';

import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {WSTETH, ARB, RETH} from '@script/MainnetParams.s.sol';

contract MainnetScripts is MainnetDeployment, Script, Test {
  uint256 internal _userPk;
  address internal _user;
  bool internal _broadcast;

  // User wallet address
  address public USER1 = vm.envAddress('ARB_SEPOLIA_PUBLIC1');
  address public USER2 = vm.envAddress('ARB_SEPOLIA_PUBLIC2');

  // Safe id
  uint256 public SAFE = vm.envUint('SAFE');

  // Collateral and debt
  uint256 public COLLATERAL = vm.envUint('COLLATERAL'); // ex: COLLATERAL=400000000000000000 (0.4 ether)
  uint256 public DEBT = vm.envUint('DEBT'); // ex: DEBT=200000000000000000000 (200 ether)

  // Collateral
  bytes32 public constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
  bytes32 public constant WSTETH = bytes32('WSTETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
  bytes32 public constant ARB = bytes32('ARB'); //0x4152420000000000000000000000000000000000000000000000000000000000
  bytes32 public constant RETH = bytes32('RETH');

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
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  // /**
  //  * @dev repays all of debt with user's COIN BALANCE
  //  */
  function repayAllDebt(uint256 _safeId, address _proxy) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.repayAllDebt.selector, address(safeManager), address(coinJoin), _safeId);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }
}
