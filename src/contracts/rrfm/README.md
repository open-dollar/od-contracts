# GEB Redemption Rate Feedback Mechanism Calculators

This folder hosts calculators that can compute redemption rates for a GEB deployment.

The folder hosts the following core calculator implementations:

- **PIRawPerSecondCalculator**: proportional integral calculator using the raw **abs(mark - index)** deviation to compute a rate
- **BasicPIRawPerSecondCalculator**: a simpler version of [PIRawPerSecondCalculator](https://github.com/reflexer-labs/geb-rrfm-calculators/blob/master/src/calculator/PIRawPerSecondCalculator.sol) with less restrictions on how the redemption rate is calculated
- **DirectRateCalculator**: this calculator emulates SAI's Vox by adding or subtracting a fixed amount from the current rate
- **PIScaledPerSecondCalculator**: proportional integral calculator using the formula: **abs(mark - index) * 10^27 / index** in order to compute a rate
- **PRawPerSecondCalculator**: proportional calculator using the raw **abs(mark - index)** deviation to compute a rate
