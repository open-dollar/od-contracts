# Accounting Engine

See [AccountingEngine.sol](/src/contracts/AccountingEngine.sol/contract.AccountingEngine.html) for more details.

## 1. Introduction

The Accounting Engine serves as the system's financial management hub, overseeing tasks such as:

- Tracking system surplus and deficit.
- Managing system debt through auctions.
- Dealing with system surplus via auctions or transfers.
- Accepting COINs (for instance, from auctions) and using them to offset DEBT.

## 2. Contract Details

### Key Methods:

**Public**

- `popDebtFromQueue`: Removes a certain amount of debt from the time-sensitive queue after the `popDebtDelay` duration has elapsed, for either settlement or auction.
- `settleDebt`: Utilizes coin balance to settle debt.
- `cancelAuctionedDebtWithSurplus`: Utilizes coins to settle debt that's in the queue.
- `auctionDebt`: Triggers an auction to liquidate portions of unsettled debt.
- `auctionSurplus`: Triggers an auction to liquidate surplus once all debt has been settled.
- `transferExtraSurplus`: Allocates (instead of auctioning it) excess surplus following debt settlement.
- `transferPostSettlementSurplus`: Allocates all remaining surplus when a Global Settlement event occurs.

**Authorized**

- `pushDebtToQueue`: Adds a specified amount of debt to a time-sensitive queue.
- `disableContract`: Deactivates both Debt and Surplus Auction Houses, clears as much debt as possible, and transfers (after `disableCooldown` delay) any leftover surplus to a designated drain address.

### Required Authorities:

- **LiquidationEngine**: needs authorization to call `pushDebtToQueue`.
- **Debt Auction House**: needs authorization to call `cancelAuctionedDebtWithSurplus`.
- **Surplus Auction House**: needs approval to modify the contract's state in the SAFE Engine.
- **Global Settlement**: needs authorization to call `disableContract`.

### Contract Parameters:

**Global**

- **SAFE Engine**: Holds the coin and debt balance, is called to settle debt.
- **Surplus Auction House**: Is called to start surplus auctions.
- **Debt Auction House**: Is called to start debt auctions.
- `postSettlementSurplusDrain`: Address to which surplus is sent following Global Settlement.
- `surplusIsTransferred`: Whether the surplus should be either auctioned off or transferred.
- `surplusDelay`: Time lag before the surplus becomes eligible for either auction or transfer.
- `popDebtDelay`: Time interval after which debt can be popped from the time-sensitive queue.
- `disableCooldown`: The waiting period following Global Settlement, after which any remaining surplus should be transferred.
- `surplusAmount`: Amount of surplus eligible for auction or transfer during each operation.
- `surplusBuffer`: Minimum surplus reserve to be maintained in the contract following an auction or transfer.
- `debtAuctionMintedTokens`: Initial quantity of Protocol Tokens offered for minting in debt auctions.
- `debtAuctionBidSize`: Chunk of debt that can be offered in each individual debt auction.

## 3. Key Mechanisms & Concepts

### Queued Debt, On Auction Debt & Unqueued Unauctioned Debt

Within the SAFE Engine's scope, the Accounting Engine maintains a single debt balance associated with the contract address. This balance is the summation of three components: the queued debt, representing debt in line for auctioning; the unqueued debt, which is currently being auctioned; and the remaining debt not undergoing auction at the moment.

The unqueued-unauctioned debt can be calculated as follows:

```
unqueuedUnauctionedDebt = debtBalance - queuedDebt - onAuctionDebt
```

Once the `unqueuedUnauctionedDebt` debt reaches the specified `debtAuctionBidSize` threshold and the cooldown period elapses, a debt auction is initiated. During this process, the overall debt of the contract remains unchanged, but the `onAuctionDebt` metric increases as the debt enters the auction phase. Simultaneously, the calculation for `unqueuedUnauctionedDebt` decreases as the debt undergoing auction is accounted for.

## 4. Gotchas

### Unqueued Unauctioned Debt underflow

The `queuedDebt` is modified through the `pushDebtToQueue` (authorized) and `popDebtFromQueue` (public) methods. They don't exclusively mirror the `debtBalance` recorded in the SAFE Engine. If an authorized contract uses `pushDebtToQueue` without transferring debt to the Accounting Engine, it could lead to an underflow issue (if `queuedDebt` exceeds `debtBalance`). This situation could potentially disrupt the contract's ability to auction debt as the `unqueuedUnauctionedDebt` calculation might underflow and revert.

## 5. Failure Modes

### Parameters misconfiguration

- High `surplusDelay` slows surplus actions.
- Low `surplusDelay` rushes surplus auctions.
- High `popDebtDelay` delays debt auctions.
- Low `popDebtDelay` risks double debt coverage.
- High `surplusAmount` risks unfilled surplus auctions.
- Low `surplusAmount` hampers surplus actions.
- High `surplusBuffer` blocks surplus auctions.
- Low `surplusBuffer` risks uncovered new debt.
- High `debtAuctionMintedTokens` dilutes protocol tokens.
- Low `debtAuctionMintedTokens` risks failed debt auctions.
- High `debtAuctionBidSize` risks unfilled debt auctions.
- Low `debtAuctionBidSize` slows debt auctions.
- Low `shutdownCooldown` risks premature surplus moves.
- High `shutdownCooldown` delays post-shutdown surplus actions.

### Post Settlement Surplus Drain misconfiguration

The `postSettlementSurplusDrain` address should be configured after the system is deployed. It's permissible to leave it unset, but doing so comes with implications: if Global Settlement is activated while this address is not specified, any surplus remaining after the settlement won't be drained. Instead, this surplus can only be used for debt elimination. It's worth noting that once Global Settlement is triggered, the address for `postSettlementSurplusDrain` becomes immutable and can't be changed.
