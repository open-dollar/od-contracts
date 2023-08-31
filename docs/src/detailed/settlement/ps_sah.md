# Post Settlement Surplus Auction House

See [PostSettlmentSurplusAuctionHouse.sol](/src/contracts/settlement/PostSettlementSurplusAuctionHouse.sol/contract.PostSettlementSurplusAuctionHouse.html) for more details.

## 1. Introduction

The Post Settlement Surplus Auction House is responsible for auctioning off the surplus coins the system has after the global settlement is triggered. The auctions resemble the [Surplus Auction House](/detailed/auctions/sah.md) auctions, with the difference that all of the protocol tokens are burned.

## 2. Contract Details

### Key Methods:

**Public**

- `increaseBidSize`: Allows users to bid on the auctions, protocol tokens are transferred in this call.
- `restartAuction`: Restarts an auction that expired with no bids.
- `settleAuction`: Settles an auction, sending the system coins to the winning bidder.

**Authorized**

- `startAuction`: Starts a new surplus auction.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
