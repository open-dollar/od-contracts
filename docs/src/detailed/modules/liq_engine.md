# Liquidation Engine

See [LiquidationEngine.sol](/src/contracts/LiquidationEngine.sol/contract.LiquidationEngine.html) for more details.

## 1. Introduction

The Liquidation Engine is the component responsible for managing the liquidation processes of SAFEs. Its primary duties include:

- Determining the liquidation status of a SAFE.
- Initiating a SAFE Saviour action to enhance the SAFE's financial health, if applicable.
- Assessing the amount of collateral required to be confiscated from a SAFE to offset its debt.
- Activating the process to seize collateral from a SAFE.
- Initiating collateral auctions.

## 2. Contract Details

### Key Functions:

**Public**

- `liquidateSAFE`: Evaluates the condition of a SAFE and commences the liquidation process if the SAFE is eligible for liquidation (and if SAFE Saviour intervention fails).

**Permissioned**

- `protectSAFE`: Selects a SAFE Saviour to defend a SAFE against liquidation.

**Authorized**

- `connectSAFESaviour`: Permits a SAFE Saviour contract to associate with a SAFE for the purpose of preventing its liquidation.
- `disconnectSAFESaviour`: Revokes permission for a SAFE Saviour contract to be linked to SAFEs.
- `removeCoinsFromAuction`: Adjusts the accounted amount of coins that are currently under auction.

### Required Authorities:

- **Collateral Auction Houses**: need authorization to call `removeCoinsFromAuction`.
- **Global Settlement**: needs authorization to call `disableContract` (and block further liquidations).

### Contract Parameters:

**Global**

- **SAFE Engine**: Holds the SAFE state, is called to confiscate the SAFE collateral and debt.
- **Accounting Engine**: The confiscated debt is transferred to the Accounting Engine balance, and pushed to its queue to be auctioned.
- `onAuctionSystemCoinLimit`: Maximum amount of system coins that can be simultaneously auctioned.

**Per Collateral Type**

- **Collateral Auction House**: Is called to start collateral auctions.
- `liquidationPenalty`: Penalty applied to the debt of the SAFE that is being liquidated. This penalty represents an excess in the amount of debt that the collateral auction needs to cover.
- `liquidationQuantity`: Max amount of debt that can be liquidated in each liquidation.

## 3. Key Mechanisms & Concepts

### Liquidation Penalty

If a SAFE is subject to liquidation carrying a specific debt amount, the Liquidation Engine initiates a collateral auction. The target debt to be covered in the auction is determined by the following equation:

```
debtToAuction = debtToCover * liquidationPenalty
```

> **Example**: Alice has a SAFE with 1000 TKN locked and a 500 COINs debt. The TKN price drops, and Alice's SAFE gets liquidated. The liquidation penalty is `1.1`, so the collateral auction will auction off Alice's 1000 TKNs, to try to cover 550 COINs of debt.

### Liquidation Quantity

The quantity of collateral and debt seized from a SAFE during liquidation is decided based on the following criteria:

- If the SAFE's debt is smaller than `liquidationQuantity`, the SAFE undergoes full liquidation.
- If the SAFE's debt surpasses `liquidationQuantity`, the SAFE is only partially liquidated, and residual debt remains.
- If the SAFE's outstanding debt crosses the `onAuctionSystemCoinLimit`, partial liquidation occurs, and any remaining debt stays in the SAFE.
- In cases of partial liquidation, a corresponding slice of collateral is seized, leaving the remaining collateral intact within the SAFE.

### SAFE Saviours

These are smart contracts authorized to intervene on a user's behalf to improve the SAFE's financial condition and prevent liquidation. To become operational, SAFE Saviour contracts must receive authorization and must be chosen by each individual user.

## 4. Gotchas

### System Coin Limit

This parameter establishes a shared upper limit for the total quantity of coins—equivalent to debt—that can be simultaneously auctioned for all kinds of collateral. Once this collective cap is reached, no additional debt auctions can occur, regardless of the type of collateral in question.

Reaching this ceiling can set off a chain reaction of consequences. For example, if a specific collateral type is unusually volatile and maxes out the debt limit through numerous auctions, it could essentially monopolize the available auction capacity, preventing other types of collateral from being auctioned. Furthermore, reaching this ceiling can freeze all new collateral auctions, affecting the liquidity and stability of the system until remedial actions are taken.

Therefore, it's vital for both users and system administrators to closely monitor how near the system is to hitting the `onAuctionSystemCoinLimit`. Breaching this limit could disrupt a wide range of operations.

> **Notice**: The `onAuctionSystemCoinLimit` is a number with RAD precision.

## 5. Failure Modes

### Parameters misconfiguration:

- High `onAuctionSystemCoinLimit` risks mass collateral liquidation.
- Low `onAuctionSystemCoinLimit` slows SAFE liquidations.
- High `liquidationPenalty` amplifies user losses.
- Low `liquidationPenalty` encourages overleveraging.
- High `liquidationQuantity` favors full SAFE liquidations.
- Low `liquidationQuantity` makes small auctions gas-inefficient.
