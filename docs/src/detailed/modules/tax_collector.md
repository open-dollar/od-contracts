# Tax Collector

See [TaxCollector.sol](/src/contracts/TaxCollector.sol/contract.TaxCollector.html) for more details.

## 1. Introduction

The Tax Collector is the module that handles the collection of taxes. It is responsible for the following:

- Storing the interest rate for each collateral type.
- Storing the tax revenue receivers.
- Calculating and distributing the tax revenue.

## 2. Contract Details

### Key Methods:

**Public**

- `taxSingle`: Calculates and distributes the tax revenue for a single collateral type.
- `taxMany`: Calculates and distributes the tax revenue for a set of collateral types.

### Contract Parameters:

**Global**

- **SAFE Engine**: Is called to update the accumulated rate for each collateral type.
- **Primary Tax Receiver**: Receives tax revenue for all collateral types.
- `globalStabilityFee`: Global stability fee applied to all collateral types.
- `maxStabilityFeeRange`: Maximum range for the stability fee to differ from 1 (no fee).

**Per Collateral Type**

- **Secondary Tax Receivers**: Addresses (and tax percentage) that receive revenue for the collateral type total stability fees.
- `stabilityFee`: Stability fee applied only to the collateral type.

## 3. Key Mechanisms & Concepts

### Primary and Secondary Tax Receivers

The contract holds 2 types of tax receivers:

- **Primary Tax Receiver**: Is a shared address across all the collateral types. It receives the remaining tax revenue after the secondary tax receivers have been paid.
- **Secondary Tax Receivers**: Is a set of addresses per collateral type, that can be set to receive a fixed percentage amount of the tax revenue of the collateral type.

### Global and Per Collateral Stability Fees

The tax (or Stability Fee) can be configured in 2 ways:

- **Global Stability Fee**: Shared across all the collateral types.
- **Per Collateral Stability Fee**: Set for each collateral type.

The final stability fee computed for a collateral type is the multiplication of both fees. To avoid retroactivity, the tax collecting routine first reads the previously stored stability fee, and then calculates and stores the new one.

## 4. Gotchas

## 5. Failure Modes

### Parameters misconfiguration:

- `maxStabilityFeeRange` too high may result in a bad calculation of the stability fee, resulting in broken collateral types (as their accumulated rate will be too low/high).
- `maxStabilityFeeRange` too low may result in a bounded value for the stability fee, bounding the final stability fee to a value very similar to 1 (no stability fee).
- `maxSecondaryTaxReceivers` too low may result in not being able to add a secondary tax receiver to a collateral type.
- Stability fees (`global * perCollateral`) too high may result in users not interested in generating debt.
- Stability fees too low may result in the protocol not being able to generate enough revenue to cover the system expenses.
