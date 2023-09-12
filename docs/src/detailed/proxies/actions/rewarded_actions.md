# Rewarded Actions

See [RewardedActions.sol](/src/contracts/proxies/actions/RewardedActions.sol/contract.RewardedActions.html) for more details.

## 1. Introduction

Maintaining the protocol's overall health often involves executing key maintenance methods. To incentivize these interactions, the Rewarded Actions Contract exists as a specialized layer that batches transactions for interacting with Jobs contracts. These Jobs contracts offer rewards to users for successfully calling specific maintenance methods critical to the protocol. By consolidating these calls into batch transactions via the Rewarded Actions Contract, users can more efficiently earn rewards while aiding in the protocol's upkeep.

## 2. Contract Details

### Key Methods:

- `startDebtAuction`: Starts a debt auction.
- `startSurplusAction`: Starts a surplus auction.
- `popDebtFromQueue`: Pops a debt block from the Accounting Engine's queue.
- `transferExtraSurplus`: Transfers surplus (instead of auctioning it).
- `liquidateSAFE`: Liquidates a SAFE.
- `updateCollateralPrice`: Fether the latest price for a collateral type to update the system.
- `updateRedemptionRate`: Triggers the redemption rate to be updated.

## 3. Key Mechanisms & Concepts

### Payment Flow

In the HAI ecosystem, when users interact with Jobs contracts for performing key maintenance tasks, the rewards for these actions come from the Stability Fee Treasury. Upon successful execution of a job, the treasury transfers these rewards internally to the user's account within the protocol. Following this, a proxy action is triggered, designed specifically to "burn" these internal coins. This burning process essentially converts the internal balance into ERC20 HAI tokens, which are then withdrawn to the user's external wallet. Thus, the process seamlessly ensures that users are rewarded in a liquid form of HAI tokens that can be freely used or traded.

## 4. Gotchas

## 5. Failure Modes
