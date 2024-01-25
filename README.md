<p align="center">
<svg width="60" height="60" viewBox="0 0 74 73" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M37.2501 0.559999C30.143 0.558021 23.1949 2.66387 17.2847 6.61115C11.3745 10.5584 6.76772 16.1698 4.04702 22.7355C1.32633 29.3013 0.613915 36.5265 1.99996 43.4971C3.38601 50.4678 6.80826 56.8709 11.8338 61.8964C16.8593 66.9219 23.2623 70.3441 30.2329 71.7301C37.2036 73.1161 44.4288 72.4038 50.9945 69.6831C57.5603 66.9624 63.1717 62.3556 67.119 56.4454C71.0663 50.5352 73.172 43.5871 73.1701 36.48C73.1674 26.9542 69.3822 17.8194 62.6464 11.0837C55.9107 4.34795 46.7758 0.56265 37.2501 0.559999ZM37.2501 63.07C31.9911 63.07 26.8502 61.5106 22.4775 58.5888C18.1048 55.6671 14.6966 51.5143 12.6841 46.6556C10.6716 41.7969 10.145 36.4505 11.171 31.2925C12.197 26.1346 14.7295 21.3967 18.4481 17.678C22.1668 13.9594 26.9047 11.4269 32.0626 10.4009C37.2206 9.37496 42.5669 9.90153 47.4256 11.9141C52.2843 13.9266 56.4371 17.3347 59.3588 21.7074C62.2806 26.0801 63.8401 31.221 63.8401 36.48C63.8414 39.9722 63.1545 43.4305 61.8187 46.6571C60.4829 49.8837 58.5243 52.8155 56.055 55.2849C53.5856 57.7543 50.6538 59.7128 47.4272 61.0486C44.2006 62.3845 40.7423 63.0713 37.2501 63.07Z" fill="#1A74EC"/>
    <path d="M37.2401 57.18C48.6723 57.18 57.9401 47.9123 57.9401 36.48C57.9401 25.0477 48.6723 15.78 37.2401 15.78C25.8078 15.78 16.54 25.0477 16.54 36.48C16.54 47.9123 25.8078 57.18 37.2401 57.18Z" fill="#1A74EC"/>
    <path d="M10.66 36.48C10.6587 39.9722 11.3456 43.4305 12.6814 46.6571C14.0172 49.8837 15.9758 52.8155 18.4451 55.2849C20.9145 57.7543 23.8462 59.7128 27.0729 61.0486C30.2995 62.3844 33.7578 63.0713 37.25 63.07V72.41C32.4818 72.4895 27.7455 71.6191 23.3172 69.8494C18.8889 68.0797 14.8572 65.4462 11.4571 62.1024C8.057 58.7586 5.35656 54.7713 3.51324 50.3732C1.66993 45.975 0.720581 41.2538 0.720581 36.485C0.720581 31.7161 1.66993 26.995 3.51324 22.5969C5.35656 18.1987 8.057 14.2114 11.4571 10.8676C14.8572 7.52378 18.8889 4.89023 23.3172 3.12054C27.7455 1.35085 32.4818 0.480438 37.25 0.559993V9.89001C33.7578 9.8887 30.2995 10.5756 27.0729 11.9114C23.8462 13.2472 20.9145 15.2057 18.4451 17.6751C15.9758 20.1445 14.0172 23.0763 12.6814 26.3029C11.3456 29.5296 10.6587 32.9878 10.66 36.48Z" fill="#6396FF"/>
    <path d="M37.24 15.78V57.18C42.73 57.18 47.9951 54.9991 51.8771 51.1171C55.7591 47.2351 57.94 41.97 57.94 36.48C57.94 30.99 55.7591 25.7249 51.8771 21.8429C47.9951 17.9609 42.73 15.78 37.24 15.78Z" fill="#6396FF"/>
</svg>
</p>
<h1 align="center">
  Open Dollar Contracts
</h1>

This repository contains the core smart contract code for Open Dollar.

# Resources

**Documentation**

- Technical Contracts docs: https://contracts.opendollar.com
- Protocol Docs: https://docs.opendollar.com

**Contract Deployments**

Addresses for testnet can be found in the app: https://app.dev.opendollar.com/stats

**Tools**

- `@opendollar/abis` - ABI interfaces are published automatically from this repo, on merge to `main` https://www.npmjs.com/package/@opendollar/abis
- `@opendollar/sdk` - Library to interact with Open Dollar smart contracts https://github.com/open-dollar/od-sdk

# Usage

## Selecting a Foundry profile

When running `forge`, you can specify the profile to use using the FOUNDRY_PROFILE environment variable. e.g. `export FOUNDRY_PROFILE=test && forge test`. Alternatively, you can add `FOUNDRY_PROFILE=test` to `.env` and run `source .env`.

## Governance Actions

OpenDollar governance follows the common pattern of:

- proposing a governance action
- queuing the governance action
- executing the governance action

We include a set of governance scripts in `script/gov` which allow DAO members to propose, queue and execute different governance actions.

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


**Steps to run tests on Anvil**
  - `anvil` 
  - open a new terminal and `yarn deploy:anvil`
  - `yarn test:coverage` to generate a `coverage-report` folder that will contain the html of the coverage report. 
  - Point your browser to `coverage-report/index.html` to view the report.

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

## Coverage Reports

Coverage testing is performed using lcov and a local Anvil fork of the contracts. First install [lcov for mac/linx](https://formulae.brew.sh/formula/lcov).

1. Start Anvil using the instructions above.

2. To generate a report, run the command:

```bash
yarn test:coverage
```

3. Open `coverage-report/index.html` to view the report.

