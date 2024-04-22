// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISettlementSurplusAuctioneer} from '@interfaces/settlement/ISettlementSurplusAuctioneer.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Math} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  SettlementSurplusAuctioneer
 * @notice This contract receives post-settlement surplus coins from the AccountingEngine and starts auctions for them
 */
contract SettlementSurplusAuctioneer is Authorizable, Modifiable, ISettlementSurplusAuctioneer {
  using Encoding for bytes;
  using Assertions for address;

  // --- Data ---

  /// @inheritdoc ISettlementSurplusAuctioneer
  uint256 public lastSurplusTime;

  // --- Registry ---

  /// @inheritdoc ISettlementSurplusAuctioneer
  IAccountingEngine public accountingEngine;
  /// @inheritdoc ISettlementSurplusAuctioneer
  ISurplusAuctionHouse public surplusAuctionHouse;
  /// @inheritdoc ISettlementSurplusAuctioneer
  ISAFEEngine public safeEngine;

  // --- Init ---

  /**
   * @param  _accountingEngine Address of the AccountingEngine
   * @param  _surplusAuctionHouse Address of the SurplusAuctionHouse
   */
  constructor(address _accountingEngine, address _surplusAuctionHouse) Authorizable(msg.sender) validParams {
    accountingEngine = IAccountingEngine(_accountingEngine.assertNonNull());
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse.assertNonNull());
    safeEngine = ISAFEEngine(address(accountingEngine.safeEngine()));
    safeEngine.approveSAFEModification(address(surplusAuctionHouse));
  }

  // --- Core Logic ---

  /// @inheritdoc ISettlementSurplusAuctioneer
  function auctionSurplus() external returns (uint256 _id) {
    if (accountingEngine.contractEnabled()) revert SSA_AccountingEngineStillEnabled();
    IAccountingEngine.AccountingEngineParams memory _accEngineParams = accountingEngine.params();
    if (block.timestamp < lastSurplusTime + _accEngineParams.surplusDelay) revert SSA_SurplusAuctionDelayNotPassed();
    lastSurplusTime = block.timestamp;
    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _amountToSell = Math.min(_coinBalance, _accEngineParams.surplusAmount);
    if (_amountToSell > 0) {
      _id = surplusAuctionHouse.startAuction(_amountToSell, 0);
      emit AuctionSurplus(_id, lastSurplusTime, _coinBalance - _amountToSell);
    }
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();

    if (_param == 'accountingEngine') accountingEngine = IAccountingEngine(_address);
    else if (_param == 'surplusAuctionHouse') _setSurplusAuctionHouse(_address);
    else revert UnrecognizedParam();
  }

  /// @notice Sets the SurplusAuctionHouse, revoking the previous one permissions and approving the new one
  function _setSurplusAuctionHouse(address _address) internal {
    safeEngine.denySAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse = ISurplusAuctionHouse(_address);
    safeEngine.approveSAFEModification(_address);
  }
}
