# Debt Auction House

See [DebtAuctionHouse.sol](/src/contracts/DebtAuctionHouse.sol/contract.DebtAuctionHouse.html) for more details.

## 1. Introduction

The Debt Auction House contract plays a crucial role in the protocol by managing and auctioning off bad debt. To achieve this, the contract mints protocol tokens, which are auctioned off to users in exchange for system coins. These system coins are then used to annihilate the corresponding bad debt from the system.

The Debt Auction House utilizes a descending bidding model. In this model, a predetermined amount of debt is up for auction. Participants bid by specifying how many protocol tokens they are willing to accept in exchange for taking on this debt. As the auction progresses, the number of protocol tokens a bidder is willing to accept decreases, leading to a more favorable exchange rate for the protocol.

This system ensures that bad debts are efficiently cleared from the protocol, while also incentivizing participants to compete for the most favorable exchange rates.

## 2. Contract Details

### Key Methods:

**Public**

- `restartAuction`: Allows for the resumption of an expired auction that has received no bids. This restarts the auction and increases the initial quantity of protocol tokens to be minted as an incentive for participation.
- `decreaseSoldAmount`: Enables users to participate in the auction by bidding. System coins are transferred during this operation.
- `settleAuction`: Finalizes an auction, distributing the protocol tokens to the winning bidder.
- `terminateAuctionPrematurely`: Ends an auction before its scheduled completion. This method creates an unbacked debt entry in the Accounting Engine and returns the system coins to the highest bidder. Note that this action can only be performed when the contract is disabled.

**Authorized**

- `startAuction`: Initiates a new debt auction.

### Contract Parameters:

- **Accounting Engine**: The address of the Accounting Engine contract that handles the system's financial records.

These methods and parameters provide a comprehensive control structure for managing bad debt through auctions, balancing both protocol and user interests.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
