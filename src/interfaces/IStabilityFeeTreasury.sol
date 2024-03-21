// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IStabilityFeeTreasury is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when an account's total allowance is modified
   * @param  _account The account whose allowance was modified
   * @param  _rad The new total allowance [rad]
   */
  event SetTotalAllowance(address indexed _account, uint256 _rad);

  /**
   * @notice Emitted when an account's per hour allowance is modified
   * @param  _account The account whose allowance was modified
   * @param  _rad The new per hour allowance [rad]
   */
  event SetPerHourAllowance(address indexed _account, uint256 _rad);

  /**
   * @notice Emitted when governance gives funds to an account
   * @param  _account The account that received funds
   * @param  _rad The amount of funds that were given [rad]
   */
  event GiveFunds(address indexed _account, uint256 _rad);

  /**
   * @notice Emitted when governance takes funds from an account
   * @param  _account The account from which the funds are taken
   * @param  _rad The amount of funds that were taken [rad]
   */
  event TakeFunds(address indexed _account, uint256 _rad);

  /**
   * @notice Emitted when an account pulls funds from the treasury
   * @param  _sender The account that triggered the pull
   * @param  _dstAccount The account that received funds
   * @param  _rad The amount of funds that were pulled [rad]
   */
  event PullFunds(address indexed _sender, address indexed _dstAccount, uint256 _rad);

  /**
   * @notice Emitted when surplus funds are transferred to the extraSurplusReceiver
   * @param  _extraSurplusReceiver The account that received the surplus funds
   * @param  _fundsToTransfer The amount of funds that were transferred [rad]
   */
  event TransferSurplusFunds(address _extraSurplusReceiver, uint256 _fundsToTransfer);

  /**
   * @notice Emitted when ERC20 coins are joined into the system
   * @param  _wad The amount of ERC20 coins that were joined [wad]
   */
  event JoinCoins(uint256 _wad);

  /**
   * @notice Emitted when treasury coins are used to settle debt
   * @param  _rad The amount of internal system coins and debt that were destroyed [rad]
   */
  event SettleDebt(uint256 _rad);

  // --- Errors ---

  /// @notice Throws when trying to pull/give/take funds from/to the treasury itself
  error SFTreasury_AccountCannotBeTreasury();
  /// @notice Throws when trying to transfer surplus funds without having settled all debt
  error SFTreasury_OutstandingBadDebt();
  /// @notice Throws when trying to transfer more funds than the treasury has
  error SFTreasury_NotEnoughFunds();
  /// @notice Throws when trying to pull funds above the account's total allowance
  error SFTreasury_NotAllowed();
  /// @notice Throws when trying to pull funds above the account's per hour allowance
  error SFTreasury_PerHourLimitExceeded();
  /// @notice Throws when trying to pull funds to the accounting contract
  error SFTreasury_DstCannotBeAccounting();
  /// @notice Throws when trying to transfer a null amount of funds
  error SFTreasury_NullTransferAmount();
  /// @notice Throws when trying to pull funds while the coin balance is below the minimum threshold
  error SFTreasury_BelowPullFundsMinThreshold();
  /// @notice Throws when trying to transfer surplus funds before the cooldown period has passed
  error SFTreasury_TransferCooldownNotPassed();
  /// @notice Throws when trying to transfer surplus funds while the treasury is below capacity
  error SFTreasury_NotEnoughSurplus();

  // --- Structs ---

  struct StabilityFeeTreasuryParams {
    // Maximum amount of internal coins that the treasury can hold
    uint256 /* RAD     */ treasuryCapacity;
    // Minimum amount of internal coins that the treasury must hold in order to allow pulling funds
    uint256 /* RAD     */ pullFundsMinThreshold;
    // Minimum amount of time that must pass between surplus transfers
    uint256 /* seconds */ surplusTransferDelay;
  }

  struct Allowance {
    // Total allowance for the given account
    uint256 /* RAD */ total;
    // Per hour allowance for the given account
    uint256 /* RAD */ perHour;
  }

  /**
   * @notice Getter for the allowance struct of a given account
   * @param  _account The account to query
   * @return __allowance Data structure containing total and per hour allowance for the given account
   */
  function allowance(address _account) external view returns (Allowance memory __allowance);

  /**
   * @notice Getter for the unpacked allowance struct of a given account
   * @param  _account The account to query
   * @return _total Total allowance for the given account
   * @return _perHour Per hour allowance for the given account
   * @dev    A null per hour allowance means that the account has no per hour limit
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _allowance(address _account) external view returns (uint256 _total, uint256 _perHour);

  /**
   * @notice Modify an address' total allowance in order to withdraw SF from the treasury
   * @param  _account The approved address
   * @param  _rad The total approved amount of SF to withdraw [rad]
   */
  function setTotalAllowance(address _account, uint256 _rad) external;

  /**
   * @notice Modify an address' per hour allowance in order to withdraw SF from the treasury
   * @param  _account The approved address
   * @param  _rad The per hour approved amount of SF to withdraw [rad]
   */
  function setPerHourAllowance(address _account, uint256 _rad) external;

  /**
   * @notice Governance transfers SF to an address
   * @param  _account Address to transfer SF to
   * @param  _rad Amount of internal system coins to transfer [rad]
   */
  function giveFunds(address _account, uint256 _rad) external;

  /**
   * @notice Governance takes funds from an address
   * @param  _account Address to take system coins from
   * @param  _rad Amount of internal system coins to take from the account [rad]
   */
  function takeFunds(address _account, uint256 _rad) external;

  /**
   * @notice Pull stability fees from the treasury
   * @param  _dstAccount Address to transfer funds to
   * @param  _wad Amount of system coins (SF) to transfer [wad]
   * @dev    The caller of this method needs to have enough allowance in order to pull funds
   */
  function pullFunds(address _dstAccount, uint256 _wad) external;

  /**
   * @notice Transfer surplus stability fees to the extraSurplusReceiver. This is here to make sure that the treasury
   *         doesn't accumulate fees that it doesn't even need in order to pay for allowances. It ensures
   *         that there are enough funds left in the treasury to account for posterior expenses
   */
  function transferSurplusFunds() external;

  /**
   * @notice Settle as much bad debt as possible (if this contract has any)
   * @return _coinBalance Amount of internal system coins that this contract has after settling debt
   * @return _debtBalance Amount of bad debt that this contract has after settling debt
   */
  function settleDebt() external returns (uint256 _coinBalance, uint256 _debtBalance);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  /// @notice Address of the CoinJoin contract
  function coinJoin() external view returns (ICoinJoin _coinJoin);
  /// @notice Address that receives surplus funds when treasury exceeds capacity (or is disabled)
  function extraSurplusReceiver() external view returns (address _extraSurplusReceiver);
  /// @notice Address of the SystemCoin contract
  function systemCoin() external view returns (ISystemCoin _systemCoin);

  // --- Data ---

  /// @notice Timestamp of the last time that surplus funds were transferred
  function latestSurplusTransferTime() external view returns (uint256 _latestSurplusTransferTime);

  /**
   * @notice Amount of internal coins a given account has pulled from the treasury in a given block hour
   * @param  _account The account to query
   * @param  _blockHour The block hour to query
   * @return _pulledPerHour Amount of coins pulled from the treasury by the account in the given block hour [rad]
   */
  function pulledPerHour(address _account, uint256 _blockHour) external view returns (uint256 _pulledPerHour);

  /**
   * @notice Getter for the contract parameters struct
   * @return _sfTreasuryParams StabilityFee parameters struct
   */
  function params() external view returns (StabilityFeeTreasuryParams memory _sfTreasuryParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _treasuryCapacity Maximum amount of internal coins that the treasury can hold [rad]
   * @return _pullFundsMinThreshold Minimum amount of internal coins that the treasury must hold in order to allow pulling funds [rad]
   * @return _surplusTransferDelay Minimum amount of time that must pass between surplus transfers [seconds]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (uint256 _treasuryCapacity, uint256 _pullFundsMinThreshold, uint256 _surplusTransferDelay);
}
