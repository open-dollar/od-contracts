// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SurplusBidActions, CommonActions} from '@contracts/proxies/actions/SurplusBidActions.sol';

/**
 * @title  PostSettlementSurplusBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract PostSettlementSurplusBidActions is SurplusBidActions {
  // --- Overrides ---

  /**
   * @dev    Post settlement it is not possible to exit system coins
   * @inheritdoc CommonActions
   */
  function _exitSystemCoins(address, uint256) internal override {}
}
