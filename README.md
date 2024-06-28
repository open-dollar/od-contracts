<p align="center">
<img width="60" height="60"  src="https://raw.githubusercontent.com/open-dollar/.github/main/od-logo.svg">
</p>
<h1 align="center">
  Open Dollar Contracts
</h1>

<p align="center">
  <a href="https://twitter.com/open_dollar" target="_blank">
    <img alt="Twitter: open_dollar" src="https://img.shields.io/twitter/follow/open_dollar.svg?style=social" />
  </a>
</p>

This repository contains the core smart contract code for Open Dollar.

# Resources

**Documentation**

- Technical Contracts docs: https://contracts.opendollar.com
- Protocol Docs: https://docs.opendollar.com

**Contract Deployments**

Addresses for can be found in the app: https://app.opendollar.com/stats

**Tools**

- `@opendollar/abis` - ABI interfaces are published automatically from this repo, on merge to `main` https://www.npmjs.com/package/@opendollar/abis
- `@opendollar/sdk` - Library to interact with Open Dollar smart contracts https://github.com/open-dollar/od-sdk

# Audits

| Audit     | Date          | Auditor                                       | Commit                                                                | Changes Since Audit                                                                | Report                                                                                                                                  |
| --------- | ------------- | --------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| contracts | October, 2023 | [Cod4rena](https://code4rena.com)             | [f401eb5](https://github.com/open-dollar/od-contracts/commit/f401eb5) | [View Changes](https://github.com/open-dollar/od-contracts/compare/f401eb5...main) | [View Report](https://code4rena.com/reports/2023-10-opendollar)                                                                         |
| app       | March, 2024   | [Quantstamp](https://www.quantstamp.com/)     | [7c9b18c](https://github.com/open-dollar/od-app/commit/7c9b18c)       | [View Changes](https://github.com/open-dollar/od-app/compare/7c9b18c...main)       | [View Report](https://certificate.quantstamp.com/full/open-dollar-d-app/f0ff4333-535d-4de6-96e0-8573623c18bf/index.html)                |
| contracts | April, 2024   | [Quantstamp](https://www.quantstamp.com/)     | [6cdc848](https://github.com/open-dollar/od-contracts/commit/6cdc848) | [View Changes](https://github.com/open-dollar/od-contracts/compare/6cdc848...main) | [View Report](https://certificate.quantstamp.com/full/open-dollar-smart-contract-audit/202828fa-eb09-4d33-beab-c1ebee11ebd1/index.html) |
| relayer   | April, 2024   | [Pashov Audit Group](https://www.pashov.net/) | [453222d](https://github.com/open-dollar/od-relayer/commit/453222d)   | [View Changes](https://github.com/open-dollar/od-relayer/compare/453222d...main)   | [View Report](https://github.com/pashov/audits/blob/master/team/pdf/OpenDollar-security-review.pdf)                                     |

A Security Scan was performed by [Pessimistic](https://pessimistic.io/) April, 2024 at [a0b7640](https://github.com/open-dollar/od-contracts/commit/a0b7640). ([View Report](https://github.com/pessimistic-io/scans/blob/main/Open%20Dollar%20Security%20Scan%20Results.pdf))

Additional audits completed prior to forking this codebase can be found here: https://github.com/hai-on-op/audit-reports

# Usage

## Basic Setup for Cloned Repo

Run:
`yarn install`,
`yarn build`,
`yarn test`

## Selecting a Foundry profile

When running `forge`, you can specify the profile to use using the FOUNDRY_PROFILE environment variable. e.g. `export FOUNDRY_PROFILE=test && forge test`. Alternatively, you can add `FOUNDRY_PROFILE=test` to `.env` and run `source .env`.

# Development

## Anvil

Start Anvil:

```bash
anvil
```

Next, copy the private key from anvil terminal output into your `.env`

```
ANVIL_RPC=http://127.0.0.1:8545
ANVIL_ONE=0x....
```

Deploy the contracts locally:

```bash
yarn deploy:anvil
```

You now have a local anvil test environment with a locally deployed and instantiated version of the Open Dollar Protocol.

> NOTE: You may need to manually verify that all required addresses were updated in `AnvilContracts.t.sol`. The script `parseAnvilDeployments.js` is not perfect.

## Anvil Testing

The following scripts are used to simulate various states of the protocol. The scripts can be found in `script/states` and are described below:

**_DebtState.s.sol_**

- `DebtState.s.sol` puts every SAFE in jeopardy of liquidation by driving the non-wstETH collateral prices down. After
  running DebtState any SAFEs can be liquidated freely for testing.

```
forge script script/states/DebtState.s.sol:DebtState --fork-url http://localhost:8545 -vvvvv
```

**_LiquidationAuction.s.sol_**

- `LiquidationAuction.s.sol` takes DebtState a step further and liquidates every SAFE on the platform. It then initiates
  and completes a single collateral auction. We also create a chunk of unbacked debt in the accounting engine which
  enables launching a debt auction. This state can be used to test liquidations, launching collateral auctions, launching
  a debt auction or viewing a completed collateral auction.

```
forge script script/states/DebtAuction.s.sol:DebtAuction --fork-url http://localhost:8545 -vvvvv
```

**_DebtAuction.s.sol_**

`DebtAuction.s.sol` takes LiquidationAuction a step further and creates a large amount of unbacked debt in the
AccountingEngine; which allows us to then create a debt auction. The debt auction is then bid on and settled. This
allows testing of viewing a completed debt auction.

```
forge script script/states/DebtAuction.s.sol:DebtAuction --fork-url http://localhost:8545 -vvvvv`
```

**_SurplusState.s.sol_**

`SurplusState.s.sol` pushes the clock forward so that the protocol accrues surplus. It can be used to test launching a
SurplusAuction.

```
forge script script/states/SurplusState.s.sol:SurplusState --fork-url http://localhost:8545 -vvvvv
```

**_SurplusAuction.s.sol_**

`SurplusAuction.s.sol` takes SurplusState a step farther, and initiates a surplus auction, bids on it and settles it.
It can be used to test viewing a completed surplus auction.`

```
forge script script/states/SurplusAuction.s.sol:SurplusAuction --fork-url http://localhost:8545 -vvvvv
```

# Tests

## Forge test

`yarn test` will run all tests in the test folder. These tests are pranked on a fork Arbitrum mainnet. Additionally, there are Sepolia deployment tests.

## Coverage Reports with Anvil

Coverage testing is performed using lcov and a local Anvil fork of the contracts. First install [lcov for mac/linx](https://formulae.brew.sh/formula/lcov).

1. Start Anvil using the instructions above.

2. To generate a report, run the command:

```bash
yarn test:coverage
```

3. Open `coverage-report/index.html` to view the report.
