# Bidding Actions

See [CollateralBidActions.sol](/src/contracts/proxies/actions/CollateralBidActions.sol/contract.CollateralBidActions.html), [DebtBidActions.sol](/src/contracts/proxies/actions/DebtBidActions.sol/contract.DebtBidActions.html), [SurplusBidActions.sol](/src/contracts/proxies/actions/SurplusBidActions.sol/contract.SurplusBidActions.html) and [PostSettlementSurplusBidActions.sol](/src/contracts/proxies/actions/PostSettlementSurplusBidActions.sol/contract.PostSettlementSurplusBidActions.html) for more details.

## 1. Introduction

These contracts serve as the interaction layer between users and the auction houses responsible for handling collateral liquidations, debt auctions, and surplus auctions respectively.

## 2. Contract Details

### Key Methods:

- `buyCollateral`: Allows users to bid on collateral auctions.
- `decreaseSoldAmount`: Allows users to bid on debt auctions.
- `increaseBidSize`: Allows users to bid on surplus auctions.
- `settleAuction`: Settles an auction and withraws the corresponding funds to the user's account.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
