// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ISurplusAuctionHouse is IAuthorizable, IDisableable, IModifiable, ICommonSurplusAuctionHouse {
  // --- Events ---

  /**
   * @notice Emitted when an auction is prematurely terminated
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was terminated
   * @param  _highBidder Who won the auction
   * @param  _raisedAmount Amount of protocol tokens raised in the auction [rad]
   */
  event TerminateAuctionPrematurely(
    uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount
  );

  // --- Errors ---

  /// @notice Throws when trying to start an auction with non-zero recycling percentage and null bid receiver
  error SAH_NullProtTokenReceiver();

  struct SurplusAuctionHouseParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 /* WAD %   */ bidIncrease;
    // How long the auction lasts after a new bid is submitted
    uint256 /* seconds */ bidDuration;
    // Total length of the auction
    uint256 /* seconds */ totalAuctionLength;
    // Receiver of protocol tokens
    address /*         */ bidReceiver;
    // Percentage of protocol tokens to recycle
    uint256 /* WAD %   */ recyclingPercentage;
  }

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _sahParams Auction house parameters struct
   */
  function params() external view returns (SurplusAuctionHouseParams memory _sahParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _bidIncrease Minimum bid increase compared to the last bid in order to take the new one in consideration [wad %]
   * @return _bidDuration How long the auction lasts after a new bid is submitted [seconds]
   * @return _totalAuctionLength Total length of the auction [seconds]
   * @return _bidReceiver Receiver of protocol tokens
   * @return _recyclingPercentage Percentage of protocol tokens to recycle [wad %]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (
      uint256 _bidIncrease,
      uint256 _bidDuration,
      uint256 _totalAuctionLength,
      address _bidReceiver,
      uint256 _recyclingPercentage
    );

  /**
   * @notice Terminate an auction prematurely.
   * @param  _id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 _id) external;
}
