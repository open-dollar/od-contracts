# Fuzzing the PI

The contracts in this folder are the fuzz scripts for the redemption rate calculators.

## Setup

To run the fuzzer, set up Echidna (https://github.com/crytic/echidna) on your machine.

Then run
```
echidna-test src/test/fuzz/PIRawPerSecondCalculatorFuzz.sol --contract PIRawPerSecondCalculatorFuzz --config echidna.yaml
```

- PIRawPerSecondCalculatorFuzz: Unit fuzz of the PIRawPerSecondCalculator
- PIScaledPerSecondCalculatorFuzz: Unit fuzz of the PIScaledPerSecondCalculator

Turning function _scrambleParams_ to public will make the script also fuzz the calculator params.

Configs are in the root of this repo (echidna.yaml). You can set the number of and depth of runs,

The contracts in this folder are modified versions of the originals in the _src_ folder. They have assertions added to test for invariants, visibility of functions modified. Running the Fuzz against modified versions without the assertions is still possible, general properties on the Fuzz contract can be executed against unmodified contracts.

Tests should only run one at a time because they interfere with each other.

## Raw per second calculator

### Test overflow / underflow bounds

To run this import the math libraries from this folder (fuzz), they will assert for any over/underflow. Echidna will find the smallest tx order and absolute values to break them. With the normal library none of the tests fail (Echidna considers reverting through a require/revert a success).

Echidna will reduce the failure values, giving insight on what would cause overflows (In practice causing a DoS on the PI).

Analyzing contract: /Users/fabio/Documents/reflexer/geb-rrfm-validators/src/test/fuzz/PIRawPerSecondCalculatorFuzz.sol:PIRawPerSecondCalculatorFuzz

assertion in getNextPriceDeviationCumulative: failed!💥  
  Call sequence:
    computeRate(0,0,0)
    getNextRedemptionRate(0,0,0) Time delay: 0x49a4 Block delay: 0x314
    getNextPriceDeviationCumulative(-6194939256869069804230533717575942564655944188480877224446373291349833454,652683388792360792399972583663993930014291629521664227289133916243383)

    proportionalTerm: -6194939256869069804230533717575942564655944188480877224446373291349833454
    int256 proportionalTerm = subtract(int(redemptionPrice), multiply(int(marketPrice), int(10**9)));
    redemptionPrice - (marketPrice * 10**9), ray

    accumulatedLeak: 652683388792360792399972583663993930014291629521664227289133916243383

assertion in getNextRedemptionRate: failed!💥  
  Call sequence:
    getNextRedemptionRate(57907308180911611479908673605988279814096989201846,47404661989147505153411213388741493402549937036869,0)

    marketPrice:     57,907,308,180,911,611,479,908.673605988279814096989201846 ray
    redemptionPrice: 47,404,661,989,147,505,153,411.213388741493402549937036869 ray
    accumulatedLeak: 0

assertion in getGainAdjustedTerms: failed!💥  
  Call sequence:
    getGainAdjustedTerms(-23371788062970084254565845771112215572058915791748042014,
    57899731751471710985816757245762420458808746828303063560812)

    proportionalTerm -23371788062970084254565845771112215572058915791748042014
    multiply(proportionalTerm, int(controllerGains.Kp)) / int(EIGHTEEN_DECIMAL_NUMBER),

    integralTerm 57899731751471710985816757245762420458808746828303063560812
    multiply(integralTerm, int(controllerGains.Ki)) / int(EIGHTEEN_DECIMAL_NUMBER)


assertion in computeRate: failed!💥  
  Call sequence:
    computeRate(0,57977137547275629594851640458481362611326169284162847457111,2)

    marketPrice 0
    redemptionPrice 57977137547275629594851640458481.362611326169284162847457111 ray
    accumulatedLeak 2

assertion in breaksNoiseBarrier: failed!💥  
  Call sequence:
    breaksNoiseBarrier(4718862,115955620669995670925172467849820848300091976137319049792204)

    piSum 4718862
    redemptionPrice 115955620669995670925172467849820.848300091976137319049792204 ray

assertion in getGainAdjustedPIOutput: failed!💥  
  Call sequence:
    getGainAdjustedPIOutput(-347231593606701011538787351400167325976194250113395288401,57937662045930367718213079440176439043030079708468109223983)

    proportionalTerm: -347231593606701011538787351400167325976194250113395288401
    integralTerm: 57937662045930367718213079440176439043030079708468109223983

Seed: 636739298399007764

Conclusion: All bounds are acceptable, exceeding the inputs expected in real world usage by far.

### Set Noise to 1 should stop the controller

Set noise barrier to 1 (constructor) and set the fuzzComputeRate to public. This should prevent the PI from updating.
assertion in fuzzComputeRate: failed!💥  
  Call sequence:
    fuzzComputeRate(1,0,0)
    fuzzComputeRate(0,0,0) Time delay: 0xe24 Block delay: 0x1

Conclusion, all bounds are acceptable, exceeding the inputs expected in real world usage.

### Fuzz the KP/Ki (huge values - > overflow/underflow bounds)

Turn on scramble params (set it to public), and use the math libraries on the fuzz directory.

assertion in fuzzKpKi: failed!💥  
  Call sequence:
    fuzzKpKi(58069245149234509005668478262702673391637997952429294128655090560955,0,1026051430264905401996164310653889541692124923928762096271402575450824,0,-30623919805852496750415144172548694499423617311971075371299306310319578)

Kp: 0
Ki: -30623919805852496750415144172548694499423617311971075371299306310319578

Conclusion: Kp should never exceed 1 wad, (Mainnet test version is 826942069420 for example), Ki should always be lower than Kp.
No risks of overflowing (DoS), but setting a bound on the Kp and Ki (that are set by governance) to one Wad fully prevents an attack (or error).

### Math

Testing basic math (without overflow prevention) and then comparing results in the end. Fuzz fuzzMath function to reexecute.
Conclusion: No invariants broken.

## Scaled per second calculator

### Test overflow / underflow bounds

To run this import the math libraries from this folder (fuzz), they will assert for any over/underflow. Echidna will find the smallest tx order and absolute values to break them. With the normal library none of the tests fail (equidna considers reverting through a require/revert a success).

Echidna will reduce the failure values, giving insight on what would cause overflows (in practice causing a DoS on the PI).

Analyzing contract: /Users/fabio/Documents/reflexer/geb-rrfm-validators/src/test/fuzz/PIRawPerSecondCalculatorFuzz.sol:PIRawPerSecondCalculatorFuzz

assertion in getNextPriceDeviationCumulative: failed!💥  
  Call sequence:
    computeRate(0,1,3)
    getNextPriceDeviationCumulative(-58149010483986169562485200136362773659683122964290783946790616067185748417,0) Time delay: 0x7d1 Block delay: 0x34

    proportionalTerm: -58149010483986169562485200136362773659683122964290783946790616067185748417
    int256 proportionalTerm = subtract(int(redemptionPrice), multiply(int(marketPrice), int(10**9)));
    redemprionPrice: 0
    redemptionPrice - (marketPrice * 10**9), ray

    accumulatedLeak: 0

assertion in getNextRedemptionRate: failed!💥  
  Call sequence:
    getNextRedemptionRate(57952421625837308745798226292812149793893,420616143862541621252520418029318092255179820,0)

    marketPrice:          57,952,421,625,837.308745798226292812149793893 ray
    redemptionPrice: 420,616,143,862,541,621.252520418029318092255179820 ray
    accumulatedLeak: 0

assertion in getGainAdjustedTerms: failed!💥  
  Call sequence:
    getGainAdjustedTerms(2763089314148825402890387489309237614087549756868779,-58125321959630514261694998940930412090863249706930312529739)

    proportionalTerm 2763089314148825402890387489309237614087549756868779
    multiply(proportionalTerm, int(controllerGains.Kp)) / int(EIGHTEEN_DECIMAL_NUMBER),

    integralTerm -58125321959630514261694998940930412090863249706930312529739
    multiply(integralTerm, int(controllerGains.Ki)) / int(EIGHTEEN_DECIMAL_NUMBER)


assertion in computeRate: failed!💥  
  Call sequence:
    computeRate(0,57970783008691158597556249551994458498522203528041,488200746221439476802077072120849311756)

    marketPrice 0
    redemptionPrice 57970783008691158597556.249551994458498522203528041 ray
    accumulatedLeak 488200746221439476802077072120849311756

assertion in breaksNoiseBarrier: failed!💥  
  Call sequence:
    breaksNoiseBarrier(128223752064814502037250733205363813897240272169882890,57925245642164835248878133054578151269892689370511246699354)

    piSum 128223752064814502037250733205363813897240272169882890
    redemptionPrice 57925245642164835248878133054578.151269892689370511246699354 ray

assertion in getGainAdjustedPIOutput: failed!💥  
  Call sequence:
    getGainAdjustedPIOutput(57913243584086103738920304827415678316107265982979098144680,0)

    proportionalTerm: 57913243584086103738920304827415678316107265982979098144680
    integralTerm: 0

Seed: 636739298399007764

### Setting noise to 1 should stop the controller

Set noise barrier to 1 (constructor) and set the fuzzComputeRate to public.
assertion in fuzzComputeRate: failed!💥  
  Call sequence:
    fuzzComputeRate(0,57996469705568727824378470337833482309739182121093,0)

Issue? Not stopping the PI, it does change with noise set to 1. Document as valid

### Fuzz the KP/Ki (huge values - > overflow/underflow bounds)

Turn on scramble params (set it to public), and use the math libraries on the fuzz directory.

assertion in fuzzKpKi: failed!💥  
  Call sequence:
    fuzzKpKi(0,58171420796809667267401044834500580967086954973147,-1787183184978591511920776653045934116821806,0)

Kp: -1787183184978591511920776653045934116821806
Ki: 0

Conclusion: Kp should never exceed 1 WAD, (Mainnet test version is 826942069420 for example), Ki should always be lower than Kp.
No risks of overflowing (DoS), but setting a bound on the Kp and Ki (that are set by governance) to one Wad fully prevents an attack (or error).
