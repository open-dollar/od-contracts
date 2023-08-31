# Collateral Auction House

See [CollateralAuctionHouse.sol](/src/contracts/CollateralAuctionHouse.sol/contract.CollateralAuctionHouse.html) for more details.

## 1. Introduction

The Collateral Auction House plays a crucial role in maintaining the stability of the HAI Protocol by handling the auction of collateral seized from undercollateralized SAFEs. The primary objective is to convert this confiscated collateral into system coins, which are then forwarded to the Accounting Engine for debt destruction.

The Collateral Auction House utilizes an increasing discount model. This encourages early bidding by incrementally increasing the discount applied to the collateral over time. The rationale behind this is to expedite the auction process and ensure that debts are covered as swiftly as possible.

## 2. Contract Details

### Key Methods:

**Public**

- `buyCollateral`: Enables holders of the system coin to participate in auctions by purchasing available collateral.

**Authorized**

- `startAuction`: Initiates a new collateral auction for the contract's specific collateral type.
- `terminateAuctionPrematurely`: Allows for the early termination of an ongoing auction, with any remaining collateral allocated to the caller's address.

### Contract Parameters

- **Liquidation Engine Address**: Specifies the address of the Liquidation Engine, the module responsible for handling the on-auction system coin limit.
- **Oracle Relayer Address**: Specifies the address of the Oracle Relayer, responsible for providing up-to-date price information.
- `minimumBid`: Sets the minimum system coin bid required to participate in collateral auctions.
- `minDiscount`: Defines the initial discount rate at which auctions commence.
- `maxDiscount`: Sets the upper limit for the discount rate that auctions can achieve.
- `perSecondDiscountUpdateRate`: Determines the rate at which the discount increases for each second the auction is live.

## 3. Key Mechanisms & Concepts

### Collateral Price Feed and Discount Model

The Collateral Auction House relies on the system's collateral price feed to determine the current market price of the collateral in terms of system coins. Upon establishing this baseline, the contract employs a dynamic discount model to calculate the auction price of the collateral. Here's how the discount model works:

- **Initial Discount**: Each auction kicks off with a predefined minimum discount. This discount is set by the `minDiscount` parameter.

- **Per-Second Discount Rate**: The contract features a rate at which the discount increases on a per-second basis. This rate is determined by the `perSecondDiscountUpdateRate` parameter.

- **Maximum Discount Cap**: Once the auction reaches the maximum allowable discount, as defined by the `maxDiscount` parameter, the auction remains at this discount level until either all the collateral is bought or the auction is prematurely terminated.

This approach ensures that the auction starts incentivizing early bids but also allows for adjustments over time, ultimately facilitating efficient price discovery and collateral liquidation.

## 4. Gotchas

## 5. Failure Modes
