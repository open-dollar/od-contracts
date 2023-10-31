// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

/**
 * @title  SAFEHandler
 * @notice This contract is spawned to provide a unique safe handler address for each user's SAFE
 * @dev    When a new SAFE is created inside HaiSafeManager, this contract is deployed and calls the SAFEEngine to add permissions to the SAFE manager
 */
contract SAFEHandler {
  /**
   * @dev    Grants permissions to the SAFE manager to modify the SAFE of this contract's address
   * @param  _safeEngine Address of the SAFEEngine contract
   */
  constructor(address _safeEngine) {
    ISAFEEngine(_safeEngine).approveSAFEModification(msg.sender);
  }
}
