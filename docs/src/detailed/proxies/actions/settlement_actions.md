# Settlement Actions

See [GlobalSettlementActions.sol](/src/contracts/proxies/actions/GlobalSettlementActions.sol/contract.GlobalSettlementActions.html) for more details.

## 1. Introduction

Following a Global Settlement, the Settlement Actions Contract plays a critical role by batching essential transactions needed to interact with the protocol. This contract simplifies user interactions and boosts efficiency by consolidating multiple calls into one, easing the transition to the system's final state. Whether claiming collateral or finalizing debts, the Settlement Actions Contract is the go-to mechanism for all post-settlement activities.

## 2. Contract Details

### Key Methods:

- `freeCollateral`: Allows users to claim their remaining collateral after a SAFE was processed.
- `prepareCoinsForRedeeming`: Deposits system coins for them to be later redeemed.
- `redeemCollateral`: Claims the corresponding collateral for a given amount of system coins deposited.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
