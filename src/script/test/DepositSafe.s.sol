// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript} from './TestHelper.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script DepositSafe --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --private-key $PK --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
// source .env && forge script DepositSafe --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --private-key $PK

contract DepositSafe is TestHelperScript {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    // address proxy = address(findOrDeploy(USER));

    // depositCollat(2, WAD / 2);
    vm.stopBroadcast();
  }

  // TODO: call from the context of the Proxy
  // TODO: need to format the bytecode to call thru the proxy

  function depositCollat(uint256 safeId, uint256 wad) public {
    // lockTokenCollateral(address(safeManager), collatJoinWETH, safeId, wad, false);
    // generateDebt(address(safeManager), taxCollector, coinJoin, safeId, wad);
    wEthToken.approve(address(safeManager), 1e18 / 2);

    (bool success,) = address(basicActions).delegatecall(
      abi.encodeWithSignature(
        'lockTokenCollateral(address,address,uint256,uint256,bool)',
        address(safeManager),
        collatJoinWETH,
        safeId,
        wad,
        false
      )
    );
    require(success, 'Delegatecall to BasicActions.lockTokenCollateral error');
  }
}

/**
 * function _generateDebt(
 *     address _user,
 *     address _collateralJoin,
 *     int256 _collatAmount,
 *     int256 _deltaDebt
 *   ) internal override {
 *     HaiProxy _proxy = _getProxy(_user);
 *     bytes32 _cType = ICollateralJoin(_collateralJoin).collateralType();
 *     (uint256 _safeId,) = _getSafe(_user, _cType);
 * 
 *     if (_cType == ETH_A) _lockETH(_user, uint256(_collatAmount));
 *     else _joinTKN(_user, _collateralJoin, uint256(_collatAmount));
 * 
 *     vm.startPrank(_user);
 * 
 *     bytes memory _callData = abi.encodeWithSelector(
 *       BasicActions.lockTokenCollateralAndGenerateDebt.selector,
 *       address(safeManager),
 *       address(taxCollector),
 *       address(collateralJoin[_cType]),
 *       address(coinJoin),
 *       _safeId,
 *       _collatAmount,
 *       _deltaDebt, // wad
 *       true
 *     );
 * 
 *     _proxy.execute(address(proxyActions), _callData);
 *     vm.stopPrank();
 *   }
 */
