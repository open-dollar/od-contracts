# Oracle Relayer

See [OracleRelayer.sol](/src/contracts/OracleRelayer.sol/contract.OracleRelayer.html) for more details.

## 1. Introduction

The Oracle Relayer is the module that handles the quoting mechanism of the system. It is responsible for the following:

- Storing the oracles addresses for each collateral type.
- Fetching and updating the price of the collateral types.
- Updating the redemption price, given the redemption rate.

## 2. Contract Details

### Key Methods:

**Public**

- `marketPrice`: Gets the market price of the system coin.
- `redemptionPrice`: Gets and updates the redemption price.
- `calcRedemptionPrice`: View method that calculates (but does not update) the current redemption price.
- `updateCollateralPrice`: Fetchs the price of a collateral type, updates the redemption price, calculates the safety and liquidation prices, and updates them in the SAFE Engine.

**Authorized**

- `updateRedemptionRate`: Updates the redemption rate.

### Required Authorities:

- **PID Rate Setter**: needs authorization to call `updateRedemptionRate`.

### Contract Parameters:

**Global**

- **SAFE Engine**: Is called to update the collateral prices on it.
- **System Coin Oracle**: Is queried to fetch the market price of the system coin.
- `redemptionRateLowerBound`: Lower bound of the redemption rate.
- `redemptionRateUpperBound`: Upper bound of the redemption rate.

**Per Collateral Type**

- **Oracle**: Is queried to fetch the price of the collateral type.
- `safetyCRatio`: Ratio applied to the collateral price to define the safety price.
- `liquidationCRatio`: Ratio applied to the collateral price to define the liquidation price.

## 3. Key Mechanisms & Concepts

### Quoting Mechanism

Each collateral type needs to have an associated oracle that quotes the collateral in terms of the denomination currency (in HAI, US Dollars). The System Coin Oracle needs to be also denominated in the same currency.

The Oracle Relayer handles the quoting mechanism, in which collateral types are quoted in terms of HAI, applying a variable rate to HAI price. The collateral price is calculated as follows:

```
collateralPrice = oraclePrice / redemptionPrice
```

### C Ratios

Safety and liquidation prices are calculated by applying a ratio to the collateral price. The safety price is calculated as follows:

```
safetyPrice = collateralPrice * safetyCRatio
liquidationPrice = collateralPrice * liquidationCRatio
```

The safety price is the price at which the SAFE is considered safe, a user may modify the SAFE collateralization as long as the resulting state is above the safety price.

The liquidation price is the price at which the SAFE is considered liquidatable, and the SAFE may be liquidated.

## 4. Gotchas

## 5. Failure Modes

### Parameters misconfiguration:

- High `safetyCRatio` limits SAFE modifications.
- `safetyCRatio` near `liquidationCRatio` makes it redundant.
- High `liquidationCRatio` may cause needless liquidations.
- Low `liquidationCRatio` encourages overleveraging.
