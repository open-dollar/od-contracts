// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISettlementSurplusAuctioneer} from '@interfaces/settlement/ISettlementSurplusAuctioneer.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Math} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';

contract SettlementSurplusAuctioneer is Authorizable, Modifiable, ISettlementSurplusAuctioneer {
  using Encoding for bytes;

  // --- Data ---
  // Last time when this contract triggered a surplus auction
  uint256 public lastSurplusTime;

  // --- Registry ---
  IAccountingEngine public accountingEngine;
  ISurplusAuctionHouse public surplusAuctionHouse;
  ISAFEEngine public safeEngine;

  // --- Init ---
  constructor(address _accountingEngine, address _surplusAuctionHouse) Authorizable(msg.sender) validParams {
    accountingEngine = IAccountingEngine(_accountingEngine);
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse);
    safeEngine = ISAFEEngine(address(accountingEngine.safeEngine()));
    safeEngine.approveSAFEModification(address(surplusAuctionHouse));
  }

  // --- Core Logic ---
  /**
   * @notice Auction surplus. The process is very similar to the one in the AccountingEngine.
   * @dev The contract reads surplus auction parameters from the AccountingEngine and uses them to
   *      start a new auction.
   */
  function auctionSurplus() external returns (uint256 _id) {
    if (accountingEngine.contractEnabled() != 0) revert SSA_AccountingEngineStillEnabled();
    IAccountingEngine.AccountingEngineParams memory _accEngineParams = accountingEngine.params();
    if (block.timestamp < lastSurplusTime + _accEngineParams.surplusDelay) revert SSA_SurplusAuctionDelayNotPassed();
    lastSurplusTime = block.timestamp;
    uint256 _amountToSell = Math.min(safeEngine.coinBalance(address(this)), _accEngineParams.surplusAmount);
    if (_amountToSell > 0) {
      _id = surplusAuctionHouse.startAuction(_amountToSell, 0);
      emit AuctionSurplus(_id, lastSurplusTime, safeEngine.coinBalance(address(this)));
    }
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override validParams {
    address _address = _data.toAddress();

    if (_param == 'accountingEngine') accountingEngine = IAccountingEngine(_address);
    else if (_param == 'surplusAuctionHouse') _setSurplusAuctionHouse(_address);
    else revert UnrecognizedParam();
  }

  function _setSurplusAuctionHouse(address _address) internal {
    safeEngine.denySAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse = ISurplusAuctionHouse(_address);
    safeEngine.approveSAFEModification(_address);
  }
}
