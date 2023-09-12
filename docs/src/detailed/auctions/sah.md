# Surplus Auction House

For more details, refer to the [SurplusAuctionHouse.sol](/src/contracts/SurplusAuctionHouse.sol/contract.SurplusAuctionHouse.html) contract.

## 1. Introduction

The Surplus Auction House is tasked with auctioning the system's surplus coins in exchange for protocol tokens. A fraction of these protocol tokens is burnt to create a deflationary effect, while the rest is transferred to a specified target address. The auction employs an ascending bidding model: a fixed number of system coins are up for auction, and participants bid by offering increasingly higher amounts of protocol tokens.

## 2. Contract Details

### Key Methods:

**Public**

- `increaseBidSize`: Enables users to participate in the auction by offering higher amounts of protocol tokens, which are transferred during this operation.
- `restartAuction`: Resets an expired auction that has not received any bids, making it available for new bids.
- `settleAuction`: Finalizes the auction, transferring the system coins to the winning bidder.
- `terminateAuctionPrematurely`: Aborts an auction before its scheduled completion. This action returns the protocol tokens to the highest bidder but is only possible when the contract is deactivated.

**Authorized**

- `startAuction`: Initiates a new surplus auction.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
