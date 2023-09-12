# PID Controller

See [PIDController.sol](/src/contracts/PIDController.sol/contract.PIDController.html) and [PIDRateSetter.sol](/src/contracts/PIDRateSetter.sol/contract.PIDRateSetter.md) for more details.

## 1. Introduction

The PID Controller is a smart contract that fine-tunes the system's redemption rate by analyzing the `deviation`, which is the discrepancy between the market and redemption prices. It performs the following tasks:

- Computes and stores the system's proportional and integral deviations.
- Applies a decay factor to the integral deviation.
- Adjusts the redemption rate by applying proportional and integral gains to the deviation.

The PID Rate Setter schedules and triggers the PID Controller's redemption rate adjustments.

## 2. Contract Details

### 2.1 PID Controller

### Key Methods:

**Authorized**

- `computeRate`: Computes the new redemption rate, applying the proportional and integral gains to the deviation (can only be called by the PID Rate Setter contract).

### Contract Parameters:

- **Seed Proposer**: Authorized address for initiating redemption rate updates.
- `integralPeriodSize`: Minimum duration required to calculate integral deviation.
- `perSecondCumulativeLeak`: Decay constant for the integral deviation.
- `noiseBarrier`: Lowest deviation percentage considered for redemption rate adjustment.
- `feedbackOutputUpperBound`: Maximum limit for the redemption rate.
- `feedbackOutputLowerBound`: Minimum limit for the redemption rate.
- `proportionalGain`: Gain factor for proportional deviation.
- `integralGain`: Gain factor for integral deviation.

### 2.2 PID Rate Setter

### Key Methods:

**Public**

- `updateRate`: Retrieves market and redemption prices from the Oracle Relayer and prompts the PID Controller to compute the new redemption rate.

### Contract Parameters:

- `updateRateDelay`: Time gap between successive redemption rate adjustments.

## 3. Key Mechanisms & Concepts

### Deviation Metrics

The PID Controller monitors the gap between market and redemption prices and stores both the proportional and integral deviations. Whenever the deviation changes, its integral component is decayed to mitigate the impact of historical deviations on future rates.

#### Proportional Deviation (`pTerm`)

It is computed as:

```
pTerm = (redemptionPrice - marketPrice) / redemptionPrice
```

#### Integral Deviation (`iTerm`)

It is calculated iteratively:

```
iTerm_n = (iTerm_(n-1) * decayFactor) + ((pTerm_n - pTerm_(n-1)) / 2)
```

### Gain Parameters

The system owner can configure the gain parameters for proportional (`pGain`) and integral (`iGain`) deviations. The redemption rate is then adjusted as follows:

```
redemptionRate = 1 + (pTerm * pGain + iTerm * iGain)
```

**Notice**: All of pTerm, iTerm, pGain, iGain can be negative, so the redemption rate can be lesser than 1 (decrease the rate). Yet the redemption rate can never be 0 or negative.

## 4. Gotchas

## 5. Failure Modes

- Invalid `seedProposer` risks stale redemption rate.
- High `noiseBarrier` hampers redemption rate adjustment.
- High `integralPeriodSize` lowers PID responsiveness.
- Over-the-top `feedbackOutputUpperBound` is likely disregarded.
- Null `feedbackOutputUpperBound` constrains positive control range.
- Excessive `feedbackOutputLowerBound` may be overlooked.
- Null `feedbackOutputLowerBound` limits negative control range.
- High `perSecondCumulativeLeak` quickens integral decay.
- Low `perSecondCumulativeLeak` amplifies integral's historical effect.
- High `kp` makes controller jittery to current deviations.
- High `ki` overemphasizes historical deviations.
