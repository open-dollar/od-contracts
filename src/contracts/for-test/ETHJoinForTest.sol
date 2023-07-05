// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ETHJoin, IETHJoin} from '@contracts/utils/ETHJoin.sol';
import {Math} from '@libraries/Math.sol';

// TODO: deprecate this contract for ETH scope HAI-207
contract ETHJoinForTest is ETHJoin {
  using Math for uint256;

  // --- Init ---
  constructor(address _safeEngine, bytes32 _cType) ETHJoin(_safeEngine, _cType) {}

  address internal constant _WETH = 0x4200000000000000000000000000000000000006;

  // NOTE: method to avoid errors in calls to `join` and `exit` from the proxy
  function collateral() external pure returns (address _collateral) {
    return _WETH;
  }

  function join(address _account, uint256 _wad) external payable {
    // NOTE: doesn't require value to be sent
    safeEngine.modifyCollateralBalance(collateralType, _account, _wad.toInt());
    emit Join(msg.sender, _account, _wad);
  }

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
