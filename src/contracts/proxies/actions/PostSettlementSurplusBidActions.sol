// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';

/**
 * @title PostSettlementSurplusBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract PostSettlementSurplusBidActions is SurplusBidActions {
  function _exitSystemCoins(address, uint256) internal override {
    // NOTE: post settlement is not possible to exit system coins
  }
}
