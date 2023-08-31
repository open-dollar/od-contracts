# Global Settlement

See [GlobalSettlement.sol](/src/contracts/settlement/GlobalSettlement.sol/contract.GlobalSettlement.html) for more details.

## 1. Introduction

The Global Settlement contract serves as the emergency brake and ultimate wind-down mechanism for the system. Its responsibilities include:

- **Triggering the System Shutdown**: Initiating the process to safely halt all operations.
- **Processing SAFEs**: Settling all Secure, Automated, Flexible, and Efficient (SAFE) accounts to determine each collateral's deficits and surplus.
- **Terminating Auctions**: Bringing all ongoing auctions to a premature end, ensuring that assets are no longer tied up.
- **Calculating Redemption Price**: Determining the value at which system coin holders can redeem their coins for backing collateral.
- **Redemption**: Enabling system coin holders to exchange their coins for the appropriate collateral, completing the shutdown process.

This contract is crucial for ensuring that, in the event of a system shutdown, all parties can walk away with assets that are rightfully theirs, thus maintaining a fair and secure environment.

## 2. Contract Details

### Key Methods:

**Public**

- `freezeCollateralType`: Captures the current market price of a specified collateral type and freezes it within the contract. This is crucial for ensuring accurate valuations during the shutdown process.
- `fastTrackAuction`: Allows for the immediate termination of ongoing collateral auctions. This function ensures that assets are returned to their rightful owners as quickly as possible during a shutdown.
- `processSAFE`: This method is responsible for settling the debts associated with SAFEs and determining any collateral deficit that exists. This ensures that all assets and liabilities are properly accounted for.
- `freeCollateral`: Post-processing of SAFEs, this function enables SAFE owners to withdraw any remaining collateral. This ensures that users recover their tied-up assets.
- `setOutstandingCoinSupply`: Sets the global coin supply (which also accounts for the system's debt). This is important for calculating how much collateral can be redeemed for each system coin.
- `calculateCashPrice`: Determines the price at which system coin holders can redeem their coins for backing collateral. This provides clarity and fairness in the redemption process.
- `prepareCoinsForRedeeming`: Allows system coin holders to deposit their coins into the contract in preparation for redemption. This sets the stage for users to reclaim their backing collateral.
- `redeemCollateral`: Executes the redemption process, transferring the appropriate amount of collateral to system coin holders who have previously deposited their coins for redemption. This is the final step in the shutdown and asset recovery process.

**Authorized**

- `shutdownSystem`: This function triggers the system shutdown, initiating all the processes mentioned above. This function can only be executed by an authorized entity.

These methods collectively enable a structured and secure way to halt system operations, settle accounts, and distribute assets in the event of a system shutdown.

### Contract Parameters:

- **Oracle Relayer**: The address used to fetch the redemption price and the collaterals price.
- **Liquidation Engine**: The address used to fetch the collateral auction houses from each collateral type.
- **Coin Join**: The Coin Join contract (to disable).
- **Collateral Join Factory**: The Collateral Join Factory contract (to disable).
- **Collateral Auction House Factory**: The Collateral Auction House Factory contract (to disable).
- **Stability Fee Treasury**: The Stability Fee Treasury contract, that needs to be disabled before the Accounting Engine to transfer its funds to it.
- **Accounting Engine**: The Accounting Engine contract, that tries after disablement to settle as much debt as possible, and transfer the remaining surplus to the post settlement drain account.
- `shutdownCooldown`: The amount of time that must pass after the system shutdown is triggered before the outstanding coin supply can be calculated.

## 3. Key Mechanisms & Concepts

### System Shutdown

The system shutdown is triggered by calling the `shutdownSystem` method, that triggers the `disableContract` method on the disableable contracts (see [Disableable.sol](/src/contracts/utils/Disableable.sol/contract.Disableable.html)). Disableable contracts implement the following tools:

- `contractEnabled`: A boolean flag that indicates whether the contract is enabled or disabled.
- `_onContractDisable` method: A routine that is triggered when the contract is disabled.
- `whenEnabled / whenDisabled` modifiers: Modifiers that can be used to restrict the execution of a method to when the contract is enabled or disabled.

### Collateral Redemption Price Calculation

The `calculateCashPrice` method plays a critical role in the Global Settlement contract by determining the rate at which each system coin can be redeemed for its underlying collateral. The method employs a complex formula to arrive at this price, ensuring an equitable distribution of collateral assets based on various dynamic factors.

The formula used to calculate the collateral redemption price (`collateralCashPrice`) is as follows:

```
collateralCashPrice =
(
    collateralDebt * accumulatedRate / collateralPrice
    - collateralShortfall
) / outstandingCoinSupply
```

**Where**:

- `collateralDebt`: Represents the aggregate debt associated with a specific collateral type, generated by SAFEs.
- `accumulatedRate`: The total accrued rate (like interest or tax rate) applied to the specific collateral type over time.
- `collateralPrice`: The most recent market price for the specific collateral type, usually fetched from a trusted oracle.
- `outstandingCoinSupply`: The total circulation of system coins, essentially the aggregate debt of the system.
- `collateralShortfall`: Quantifies the deficit in terms of system coins for the collateral type.
  > If SAFEs for a particular collateral type are under-collateralized, this value will capture the shortfall. Conversely, if SAFEs are over-collateralized, owners are entitled to withdraw the surplus.

#### Redemption Mechanism:

Once the `collateralCashPrice` is calculated, users can redeem their system coins for the backing collateral using the following formula:

```
redeemableCollateral = coinAmount * collateralCashPrice
```

This ensures that each coin is redeemable for a fair portion of collateral, aiming to clear out both coins and collateral from the system by the end of the Global Settlement process.

> **Notice**: The design of this formula is such that by the end of the redemption process, the system should ideally have neither excess coins nor remaining collateral. It provides a balanced mechanism for winding down system operations and returning assets to participants.

## 4. Gotchas

## 5. Failure Modes

### Parameters Misconfiguration

- A too-low `shutdownCooldown` risks premature shutdown, leading to inaccurate collateral redemption prices due to incomplete auctions and unprocessed SAFEs.
- A too-high `shutdownCooldown` prolongs the waiting period for users to redeem their coins for backing collateral, causing potential liquidity issues.

### Incorrect Authorizations or State

This contract requires to have authorization in the following contracts:

- SAFEEngine
- OracleRelayer
- LiquidationEngine
- CollateralAuctionHouseFactory
- CoinJoin
- CollateralJoinFactory
- StabilityFeeTreasury
- AccountingEngine

Should one of this authorizations be missing, the contract will not work as expected, reverting on the `shutdownSystem` routine.

The routine also requires all above contracts to be enabled. Should one of these contracts have been manually disabled, the routine will revert.
