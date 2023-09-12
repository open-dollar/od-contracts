# Stability Fee Treasury

See [StabilityFeeTreasury.sol](/src/contracts/StabilityFeeTreasury.sol/contract.StabilityFeeTreasury.html) for more details.

## 1. Introduction

The Stability Fee Treasury functions as a specialized contract designed for managing protocol fees that are not factored into the system's surplus or deficit calculations. Unlike locked funds, the funds within this contract remain liquid and can be flexibly utilized by the system owner. Its key responsibilities encompass:

- Facilitating the disbursement of rewards for maintenance tasks.
- Utilizing funds to address unbacked debt.
- Managing diverse payments initiated by the system owner.
- Replenishing the system's surplus/deficit sheets when the treasury surpasses its predefined capacity.

## 2. Contract Details

### Key Methods:

**Public**

- `settleDebt`: This function efficiently allocates available funds to cover unbacked debt within the treasury's accounting.
- `transferSurplusFunds`: This operation addresses outstanding debt to the maximum extent achievable and transfers any excess funds beyond the capacity back to the system's surplus/deficit sheets.

**Permissioned**

- `takeFunds`: Enables the authorized withdrawal of funds from a consenting address to the treasury.
- `pullFunds`: Allows an address with sufficient allowance to withdraw funds from the treasury.

**Authorized**

- `setTotalAllowance`: Grant an address the permission to withdraw funds from the treasury up to a specified limit.
- `setPerHourAllowance`: Assign a per-hour withdrawal limit to an address, allowing them to pull funds from the treasury within this constraint.
- `giveFunds`: Move funds from the treasury to a designated address.
- `disableContract`: Swiftly transfer all available funds from the contract to a predetermined drainage address.

### Required Authorities:

- **Global Settlement**: needs authorization to call `disableContract`.

### Contract Parameters:

- **SAFEEngine**: Query and settle the treasury's coin and debt balance.
- **Extra Surplus Receiver**: Who receives the funds that are above the treasury's capacity (usually Accounting Engine).
- **CoinJoin**: Used to join ERC20 HAI into the system.
- `treasuryCapacity`: Maximum amount of funds that the treasury can hold (before transferring to the extra surplus receiver).
- `pullFundsMinThreshold`: Minimum amount of funds that the treasury must hold to be able to pull funds from it.
- `surplusTransferDelay`: Minimum delay between transfers of funds to the extra surplus receiver.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
