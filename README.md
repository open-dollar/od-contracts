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
| 2. od-app | March, 2024 | [Quantstamp](https://www.quantstamp.com/)  | [7c9b18c](https://github.com/open-dollar/od-app/commit/7c9b18c) | [View Changes](https://github.com/open-dollar/od-app/compare/7c9b18c...main) | [View Report](https://certificate.quantstamp.com/full/open-dollar-d-app/f0ff4333-535d-4de6-96e0-8573623c18bf/index.html) |
| 3. od-contracts | April, 2024 | [Pessimistic](https://pessimistic.io/) | [a0b7640](https://github.com/open-dollar/od-contracts/commit/a0b7640) | [View Changes](https://github.com/open-dollar/od-contracts/compare/a0b7640...main) | Report to be published |
| 4. od-contracts | April, 2024 | [Quantstamp](https://www.quantstamp.com/) | [6cdc848](https://github.com/open-dollar/od-contracts/commit/6cdc848) | [View Changes](https://github.com/open-dollar/od-contracts/compare/6cdc848...main) | [View Report](https://certificate.quantstamp.com/full/open-dollar-smart-contract-audit/202828fa-eb09-4d33-beab-c1ebee11ebd1/index.html) |
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

# Governance 

OpenDollar governance follows the common pattern of:
- generating a governance proposal
- submitting a governance proposal
- queuing the governance proposal
- executing the governance proposal

We include a set of governance scripts in `script/gov` which allow DAO members to propose, queue and execute different governance actions.

## Governance CLI  

```bash
yarn propose [action flag] [option flag] [path to input json]
```

All available flags can also be viewed with

```bash
yarn propose --help
```

The input for the proposal is a json file in the "gov-inputs/[network]" folder.  You can find basic templates in these folders.

All JSON inputs have these required fields:
- `chainid`: the chainId of the desired network.
- `network`: the desired network to be submitted on.
- `proposalType`: the type of proposal.  This must be in camel case with the first letter capitalized e.g. "AddCollateral"
- `ODGovernor_Address`: the address of the OD_Governor.  if you don't want to enter this manually use the `--auto` flag.
- `description`:  a description of the proposal being made.

Contract addresses with the "_Address" suffix can be automatically added by the generation script with the `--auto` flag. 

For example:
```
yarn propose -g --auto /gov-input/anvil/new-AddCollateral.json
```
will fill in`ProtocolToken_Address, ODGovernor_Address, SAFEEngine_Address, OracleRelayer_Address,  LiquidationEngine_Address, TaxCollector_Address, GlobalSettlement_Address` from `script/anvil/deployment/AnvilContracts.t.sol`

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

The JSON output may also include extra params for informative purposes and for execution params for the scripts themselves.  Please do not alter the generated outputs in any way.  This will invalidate the proposal.

## Steps for submitting a proposal

1. Fill in necessarry data in the input Json template.
2. Generate the Proposal with
```bash
 yarn propose -g --auto /gov-input/new-ProposalType.json
 ```
3. If you haven't delegated your tokens you can delegate to yourself with 
```bash
yarn propose -d /gov-output/11111111-proposalType.json
```
4. Commit and push your changes so someone else can use the generate script to with the same params to verify the output is correct.
5. After Verification, Submit the proposal with 
```bash
yarn propose -s /gov-output/11111111-proposalType.json
```
6. Vote on a proposal with 
```bash
yarn propose -v /gov-output/11111111-proposalType.json
```
7. Queue a proposal with 
```bash
yarn propose -q /gov-output/11111111-proposalType.json
```
8. Execute a proposal with 
```bash
yarn propose -x /gov-output/11111111-proposalType.json
```

**note:**
If you want to use the `--delegate` flag to delegate your tokens, you must add the `ProtocolToken_Address` field to the input json, or use the `--auto` flag when generating the proposal.

## Proposal Types

### Add Collateral

Add a new ERC20 as collateral to the system.

Template: [`new-AddCollateral.json`](gov-input/anvil/new-AddCollateral.json)

**Required json fields**

- newCollateralAddress: the token address of the proposed collateral to be added.
- newCollateralType: the symbol of the collateral token e.g. ARB
- SAFEEngineCollateralParams:
    - collateralDebtCeiling: RAD, The maximum amount of debt that can be generated with the collateral type
    - collateralDebtFloor: RAD, The minimum amount of debt that must be generated by a SAFE using the collateral
- TaxCollectorCollateralParams:
    - stabilityFee: RAY, the per collateral stability fee.
- LiquidationEngineCollateralParams:
    - newCAHChild: This will be automatically added in the generation script. you can leave this empty.
    - liquidationPenalty: WAD, Penalty applied to every liquidation involving this collateral type.
    - liquidationQuantity: RAD, Max amount of system coins to request in one auction for this collateral type.
- OracleRelayerCollateralParams: 
    - delayedOracle: Usually a DelayedOracle that enforces delays to fresh price feeds.
    - safetyCRatio: RAY, CRatio used to compute the 'safePrice' - the price used when generating debt in SAFEEngine.
    - liquidationCRatio: RAY, CRatio used to compute the 'liquidationPrice' the price used when liquidating SAFEs.

This script proposes adding a new collateral to the system (deploys new contracts via the collateral join, collateral auction house factories and it adds the correct authorizations to the needed contracts).

### Modify Parameters

Modify any parameters in a `Modifiable.sol` contract.

Template: [`new-ModifyParameters.json`](gov-input/anvil/new-ModifyParameters.json)

**Required JSON vars:**

- `objectArray`: each object in the array can be a param to be modified.  Each object must contain:
    - `target`: the address of the target contract.
    - `param`: the name of the param to be modified.
    - `type`: the data type of the input data.
    - `data`: the input data.  this can be a string, uint or an address.  depending on the requirement of the parameter that is being modified.

### Update PIDController Params

Update the redemption rate PI controller.

Template: [`new-UpdatePIDController.json`](gov-input/anvil/new-UpdatePIDController.json)

To update the PI controller you simply make a ModifyParameters proposal with all the PI controller params you would like to modify listed as individual params in the `objectArray`.


> NOTE: see [`IPIDController.sol`](src/interfaces/IPIDController.sol) for more information about this.

### ERC20 Transfer

Transfer ERC20 tokens from the TimelockController or any target contract.

Template: [`newERC20Transfer.json`](gov-input/anvil/newERC20Transfer.json)

You can propose multiple transfers in the same proposal by adding multiple transfer objects to the `objectArray`

**Required json vars:**
- `objectArray`: each object in the objectArray is a proposed transfer.
    - `erc20Token`: the address of the token to be transfered
    - `transferTo`: the address of the token recipient
    - `amount`: the amount to be transfered in wei.

### Add Nitro Rewards

Add rewards to the Camelot Nitro pool

