// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IPostSettlementSurplusAuctionHouse is IAuthorizable, IModifiable, ICommonSurplusAuctionHouse {
  // --- Structs ---

  struct PostSettlementSAHParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 /* WAD %   */ bidIncrease;
    // How long the auction lasts after a new bid is submitted
    uint256 /* seconds */ bidDuration;
    // Total length of the auction
    uint256 /* seconds */ totalAuctionLength;
  }

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _pssahParams The contract parameters struct
   */
  function params() external view returns (PostSettlementSAHParams memory _pssahParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _bidIncrease A percentage of the last bid that needs to be added in order to take the new bid in consideration
   * @return _bidDuration The duration of the bid after which an auction is considered finished
   * @return _totalAuctionLength The total duration of the auction after which an auction is considered finished
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _bidIncrease, uint256 _bidDuration, uint256 _totalAuctionLength);
}
