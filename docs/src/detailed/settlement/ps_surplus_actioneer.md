# Settlement Surplus Actioneer

See [SettlementSurplusActioneer.sol](/src/contracts/settlement/SettlementSurplusAuctioneer.sol/contract.SettlementSurplusAuctioneer.html) for more details.

## 1. Introduction

The Settlement Surplus Auction Module facilitates the auctioning of surplus coins held by the system following the activation of a global settlement. The module's purpose is grounded in the idea that without conducting an auction, the total circulating coins might fall short of the overall system debt. This imbalance could lead to an increased redemption price for collateral. By orchestrating surplus auctions, the system guarantees an equitable redemption price, while also deterring ill-intentioned actors from exploiting a global settlement to acquire collaterals at a discounted rate.

## 2. Contract Details

### Key Methods:

**Public**

- `auctionSurplus`: Triggers a surplus auction and starts the cooldown period.

### Contract Parameters:

- **Accounting Engine**: Used to fetch the surplus auction parameters.
- **Surplus Auction House**: The Post Settlement Surplus Auction House contract.

> **Notice**: The contract reads the parameters from the Accounting Engine to define the surplus auction cooldown period and the size of the auctions.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
