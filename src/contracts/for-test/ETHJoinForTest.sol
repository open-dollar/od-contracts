// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ETHJoin} from '@contracts/utils/ETHJoin.sol';
import {Math} from '@libraries/Math.sol';

/*
    Here we provide ETHJoin adapter (for native Ether)
    to connect the SAFEEngine to arbitrary external token implementations,
    creating a bounded context for the SAFEEngine. 
    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.
    Adapters need to implement two basic methods:
      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system
*/

contract ETHJoinForTest is ETHJoin {
  using Math for uint256;

  // --- Init ---
  constructor(address _safeEngine, bytes32 _cType) ETHJoin(_safeEngine, _cType) {}

  address internal constant _WETH = 0x4200000000000000000000000000000000000006;

  // NOTE: method to avoid errors in calls to `join` and `exit` from the proxy
  // TODO: normalize tests and remove these methods
  function collateral() external view returns (address _collateral) {
    return _WETH;
  }

  function join(address _account, uint256 _wad) external payable {
    // NOTE: doesn't require value to be sent
    safeEngine.modifyCollateralBalance(collateralType, _account, _wad.toInt());
    emit Join(msg.sender, _account, _wad);
  }
}
