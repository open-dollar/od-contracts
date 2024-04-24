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

| Audit | Date | Auditor | Commit | Changes Since Audit | Report |
|--------------|------|---------|--------|---------------------|--------|
| 1. od-contracts| October, 2023 | [Cod4rena](https://code4rena.com) | [f401eb5](https://github.com/open-dollar/od-contracts/commit/f401eb5) | [View Changes](https://github.com/open-dollar/od-contracts/compare/f401eb5...main) | [View Report](https://code4rena.com/reports/2023-10-opendollar) |
| 2. od-app | March, 2024 | [Quantstamp](https://www.quantstamp.com/)  | [7c9b18c](https://github.com/open-dollar/od-app/commit/7c9b18c) | [View Changes](https://github.com/open-dollar/od-app/compare/7c9b18c...main) | Report to be published |
| 3. od-contracts | April, 2024 | [Pessimistic](https://pessimistic.io/) | [a0b7640](https://github.com/open-dollar/od-contracts/commit/a0b7640) | [View Changes](https://github.com/open-dollar/od-contracts/compare/a0b7640...main) | Report to be published |
| 4. od-contracts | April, 2024 | [Quantstamp](https://www.quantstamp.com/) | [6cdc848](https://github.com/open-dollar/od-contracts/commit/6cdc848) | [View Changes](https://github.com/open-dollar/od-contracts/compare/6cdc848...main) | Report to be published |
| 5. od-relayer | April, 2024 | [Pashov Audit Group](https://www.pashov.net/) | [453222d](https://github.com/open-dollar/od-relayer/commit/453222d) | [View Changes](https://github.com/open-dollar/od-relayer/compare/453222d...main) | [View Report](https://github.com/pashov/audits/blob/master/team/pdf/OpenDollar-security-review.pdf) |

Additional audits completed prior to forking this codebase can be found here: https://github.com/hai-on-op/audit-reports

# Usage

## Basic Setup for Cloned Repo

Run:
`yarn install`,
`yarn build`,
`yarn test`

## Selecting a Foundry profile

When running `forge`, you can specify the profile to use using the FOUNDRY_PROFILE environment variable. e.g. `export FOUNDRY_PROFILE=test && forge test`. Alternatively, you can add `FOUNDRY_PROFILE=test` to `.env` and run `source .env`.

## Governance Actions

OpenDollar governance follows the common pattern of:

- proposing a governance action
- queuing the governance action
- executing the governance action

We include a set of governance scripts in `script/testScripts/gov` which allow DAO members to propose, queue and execute different governance actions.

> NOTE: It is important that you use the `governance` profile when running the different scripts otherwise the reading and writing of JSON files will not work.

### Overview

#### General Files

- [`JSONScript.s.sol`](script/testScripts/gov/JSONScript.s.sol): provides functionality for building JSON objects for proposing governance actions, parsing the proposal id for queuing proposals and parsing JSON objects for execution of the proposals.

#### Proposing Governance Actions

The current list of governance operations that can be proposed:

- Add Collateral: Adding a new collateral type to the system which can be borrowed against
- Update NFT Renderer: Sets the canonical NFT Renderer contract on Vault721

The input for the proposal is specific to the proposal and what that proposal requires.

The output is always a JSON file which includes at least the following `proposalParams`:

```
{
    "proposalId": uint256,
    "targets": address[],
    "values": uint256[]
    "calldatas": bytes[],
    "description": string,
    "descriptionHash": bytes32
}
```

The JSON output may also include some extra params just for informative purposes.

##### Add Collateral

[`ProposeAddCollateral.s.sol`](script/testScripts/gov/AddCollateralAction/ProposeAddCollateral.s.sol)

**Required env vars:**

- `GOV_EXECUTOR_PK`: private key of the governance executor
- `GOVERNANCE_ADDRESS`: address of OD Governance
- `GLOBAL_SETTLEMENT_ADDRESS`: address of the global settlement contract
- `ADD_COLLATERAL_NEW_COLLATERAL_TYPE`: bytes32 value of the new collateral type
- `ADD_COLLATERAL_NEW_COLLATERAL_ADDRESS`: address of the new collateral address
- `ADD_COLLATERAL_MINIMUM_BID`: minimum bid for the collateral auctions (wad)
- `ADD_COLLATERAL_MIN_DISCOUNT`: minimum discount for the collateral auctions (wad %)
- `ADD_COLLATERAL_MAX_DISCOUNT`: maximum discount for the collateral auctions (wad %)
- `ADD_COLLATERAL_PER_SECOND_DISCOUNT_UPDATE_RATE`: Per second rate at which the discount is updated (ray)

This script proposes adding a new collateral to the system (deploys new contracts via the collateral join and collateral auction house factories).

##### Update NFT Renderer

[`ProposeUpdateNFTRenderer.s.sol`](script/testScripts/gov/UpdateNFTRendererAction/ProposeUpdateNFTRenderer.s.sol)

**Required env vars:**

- `GOV_EXECUTOR_PK`: private key of the governance executor
- `GOVERNANCE_ADDRESS`: address of OD Governance
- `VAULT_721_ADDRESS`: address of the Vault721 contract
- `ORACLE_RELAYER_ADDRESS`: address of the oracle relayer
- `TAX_COLLECTOR_ADDRESS`: address of the tax collector
- `COLLATERAL_JOIN_FACTORY_ADDRESS`: address of the collateral join factory

This script proposes setting a new NFTRenderer contract on the Vault721 contract (deploys new NFTRenderer contract).

##### Update Block Delay

[`ProposeUpdateBlockDelay.s.sol`](script/testScripts/gov/UpdateBlockDelayAction/ProposeUpdateBlockDelay.s.sol)

**Required env vars:**

- `GOV_EXECUTOR_PK`: private key of the governance executor
- `GOVERNANCE_ADDRESS`: address of OD Governance
- `VAULT_721_ADDRESS`: address of the Vault721 contract
- `BLOCK_DELAY`: the number of blocks to wait before being able to transfer after collateral or debt has been updated for allowlisted addresses

This script proposes setting a new block delay on the Vault721 contract.

##### Update Time Delay

[`ProposeUpdateTimeDelay.s.sol`](script/testScripts/gov/UpdateTimeDelayAction/ProposeUpdateTimeDelay.s.sol)

**Required env vars:**

- `GOV_EXECUTOR_PK`: private key of the governance executor
- `GOVERNANCE_ADDRESS`: address of OD Governance
- `VAULT_721_ADDRESS`: address of the Vault721 contract
- `TIME_DELAY`: the amount of time to wait before being able to transfer after collateral or debt has been updated for non-allowlisted addresses

This script proposes setting a new time delay on the Vault721 contract.

##### Update PIDController Params

[`ProposeUpdatePidController.s.sol`](script/testScripts/gov/UpdatePidControllerAction/ProposeUpdatePidController.s.sol)

**Required env vars:**

- `GOV_EXECUTOR_PK`: private key of the governance executor
- `GOVERNANCE_ADDRESS`: address of OD Governance
- `PID_CONTROLLER_ADDRESS`: address of PID controller
- `SEED_PROPOSER`: new seed proposer address
- `NOISE_BARRIER`: new noise barrier value
- `INTEGRAL_PERIOD_SIZE`: new integral period size value
- `FEEDBACK_OUTPUT_UPPER_BOUND`: new feedback output upper bound value
- `FEEDBACK_OUTPUT_LOWER_BOUND`: new feedback output lower bound value
- `PER_SECOND_CUMULATIVE_LEAK`: new per second cumulative leak value
- `KP`: new kp value
- `KI`: new ki value
- `PRICE_DEVIATION_CUMULATIVE`: new deviation observation integral value

> NOTE: see [`IPIDController.sol`](src/interfaces/IPIDController.sol) for more information about this.

This script proposes updating params on the PIDController contract.

#### Queuing Governance Actions

**Required env vars:**

- `GOVERNANCE_ADDRESS`: address of OD Governance
- `JSON_FILE_PATH`: the path to the desired JSON proposal file
- `GOV_EXECUTOR_PK`: the private key of the queuer of the governance action

[`QueueProposal.s.sol`](script/testScripts/gov/QueueProposal.s.sol) is used to queue a proposal given the path of the JSON file which you want, e.g. `export JSON_FILE_PATH=gov-output/1-add-collateral-proposal.json`.

This script extracts the proposal id and queues the proposal via the OD governance contract. This script can be used arbitrarily for any proposal.

#### Executing Governance Actions

**Required env vars:**

- `GOVERNANCE_ADDRESS`: address of OD Governance
- `JSON_FILE_PATH`: the path to the desired JSON proposal file
- `GOV_EXECUTOR_PK`: the private key of the executor of the governance action

[`ExecuteProposal.s.sol`](script/testScripts/gov/ExecuteProposal.s.sol) is used to execute a proposal given the path of the JSON file you want, e.g. `export JSON_FILE_PATH=gov-output/1-add-collateral-proposal.json`.

The script extracts the necessary execution params from the JSON-the same params used during the proposal and executes the proposal. This script can be used arbitrarily for any proposal.

##### ERC20 Transfer

[`ProposeERC20Transfer.s.sol`](script/testScripts/gov/ProposeERC20Transfer.s.sol)

> NOTE: This script uses `transferFrom` to allow the governance to manage transfers from governance balance but also to allow the governance to transfer tokens from any address to any address

**Required env vars:**

- `GOV_EXECUTOR_PK`: private key of the governance executor
- `GOVERNANCE_ADDRESS`: address of OD Governance
- `ERC20_TRANSFER_TOKEN_ADDRESS`: address of the ERC20 contract
- `ERC20_TRANSFER_FROM_ADDRESS`: address of the sender of the ERC20 tokens
- `ERC20_TRANSFER_RECEIVER_ADDRESS`: address of the receiver of the ERC20 tokens
- `ERC20_TRANSFER_AMOUNT`: amount to be transferred

This script proposes transferring ERC20 tokens from one address to another.

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
