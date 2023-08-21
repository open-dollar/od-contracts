// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IPostSettlementSurplusAuctionHouse is IAuthorizable, IModifiable, ICommonSurplusAuctionHouse {
  struct PostSettlementSAHParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 bidIncrease; // [wad]
    // How long the auction lasts after a new bid is submitted
    uint256 bidDuration; // [seconds]
    // Total length of the auction
    uint256 totalAuctionLength; // [seconds]
  }

  // --- Params ---
  function params() external view returns (PostSettlementSAHParams memory _pssahParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _bidIncrease, uint256 _bidDuration, uint256 _totalAuctionLength);
}
