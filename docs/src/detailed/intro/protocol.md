# HAI Protocol 101

## HAI Framework Mechanics

### What is HAI?

- **Low-Cost**: The HAI protocol is deployed on the Optimism network, offering significantly low gas fees for transactions.
- **Dollar-Denominated**: Both the system coin and the collaterals are denominated in US Dollar.
- **Collateral-Backed**: A diverse basket of collateral types backs the minting of the system coin.
- **Control-Pegged**: A PID controller dynamically adjusts the funding rate to balance value transfer between minters (debtors) and holders (creditors).
- **Settleable**: The system can undergo a Global Settlement, during which all debts are squared and HAI holders can redeem tokens for a share of the collateral pool, regardless of whether they have outstanding debts.

### Glossary

#### Units of Measurement

- `WEI`: The base unit for raw ERC20 amounts.
- `WAD`: A unit with **18 decimal places**, used for representing balances.
- `RAY`: A unit with **27 decimal places**, utilized for rate computations.
- `RAD`: A unit with **45 decimal places**, employed for calculating owed amounts.
  > **Note**: The [Math Library](/src/libraries/Math.sol/library.Math.html) handles all unit multiplications and divisions.

#### Tokens

- `systemCoin`: The ERC20 stablecoin issued by HAI.
- `protocolToken`: The ERC20 governance token, used for system parameter voting and participating in debt/surplus auctions.
- `collateral`: Any ERC20 token that serves as collateral, enhancing the corresponding `cType` balance.

#### Key Concepts

- `cType`: Represents a unique identifier for a collateral type within the HAI system.
- `COIN`: An internal balance of system coins convertible to `systemCoin` on a `1:1` basis.
- `DEBT`: An internal ledger entry representing unbacked debt, erasable with `COIN` on a `1:1` basis.
- `SAFE`: A vault-like contract holding collateral and generating `COINs`, which may also accrue `DEBT`.
  - `lockedCollateral`: The collateral amount held within a `SAFE`.
  - `generatedDebt`: The debt incurred by a `SAFE` during the `COIN` generation process. Note that it does **NOT** correlate directly to the amount of `COINs` generated.
  - **Liquidation**: A process triggered for under-collateralized SAFEs, wherein their `generatedDebt` is moved to the system's `DEBT` and collateral is seized for auction to cancel out the `DEBT`.
- `redemptionPrice`: The internal price at which system coins can be exchanged for collateral.
- `targetPrice`: A reference price utilized to adjust the `redemptionPrice`, often aligned with market price.
- `redemptionRate`: Governs how the `redemptionPrice` changes over time, essentially functioning as the system's funding rate.
- `stabilityFee`: A separate interest rate, unconnected to the `redemptionRate`, applied to user debts and collected by the system.
- `accumulatedRate`: Reflects the compounded `stabilityFee` applied to a `cType`, determining the relationship between `generatedDebt` and the `COINs` produced.

This guide aims to provide a comprehensive understanding of HAI's framework and its intricacies. Armed with this knowledge, you'll be better equipped to interact with the protocol effectively.
