# Open Dollar

This repository contains the core smart contract code for Open Dollar, a GEB fork. GEB is the abbreviation of [Gödel, Escher and Bach](https://en.wikipedia.org/wiki/G%C3%B6del,_Escher,_Bach) as well as the name of an [Egyptian god](https://en.wikipedia.org/wiki/Geb).

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

- [`JSONScript.s.sol`](script/gov/JSONScript.s.sol): provides functionality for building JSON objects for proposing governance actions, parsing the proposal id for queuing proposals and parsing JSON objects for execution of the proposals.

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

[`ProposeAddCollateral.s.sol`](script/gov/AddCollateralAction/ProposeAddCollateral.s.sol)

**Required env vars:**

- `GOVERNANCE_ADDRESS`: address of OD Governance
- `GLOBAL_SETTLEMENT_ADDRESS`: address of the global settlement contract
- `ADD_COLLATERAL_NEW_COLLATERAL_TYPE`: bytes32 value of the new collateral type
- `ADD_COLLATERAL_NEW_COLLATERAL_ADDRESS`: address of the new collateral address
- `ADD_COLLATERAL_MINIMUM_BID`: minimum bid for the collateral auctions (wad)
- `ADD_COLLATERAL_MIN_DISCOUNT`: minimum discount for the collateral auctions (wad %)
- `ADD_COLLATERAL_MAX_DISCOUNT`: maximum discount for the collateral auctions (wad %)
- `ADD_COLLATERAL_PER_SECOND_DISCOUNT_UPDATE_RATE`: Per second rate at which the discount is updated (ray)

This script proposes adding a new collateral to the system (deploys new contracts via the collateral join and collateral auction house factories) and outputs a JSON output with the `proposalParams`.

##### Update NFT Renderer

[`ProposeUpdateNFTRenderer.s.sol`](script/gov/UpdateNFTRendererAction/ProposeUpdateNFTRenderer.s.sol)

**Required env vars:**

- `GOVERNANCE_ADDRESS`: address of OD Governance
- `VAULT_721_ADDRESS`: address of the Vault721 contract
- `ORACLE_RELAYER_ADDRESS`: address of the oracle relayer
- `TAX_COLLECTOR_ADDRESS`: address of the tax collector
- `COLLATERAL_JOIN_FACTORY_ADDRESS`: address of the collateral join factory

This script proposes setting a new NFTRenderer contract on the Vault721 contract (deploys new NFTRenderer contract) and outputs a JSON output with the `proposalParams`.

#### Queuing Governance Actions

**Required env vars:**

- `GOVERNANCE_ADDRESS`: address of OD Governance
- `JSON_FILE_PATH`: the path to the desired JSON proposal file
- `GOV_EXECUTOR_PK`: the private key of the queuer of the governance action

[`QueueProposal.s.sol`](script/gov/QueueProposal.s.sol) is used to queue a proposal given the path of the JSON file which you want, e.g. `export JSON_FILE_PATH=gov-output/1-add-collateral-proposal.json`.

This script extracts the proposal id and queues the proposal via the OD governance contract. This script can be used arbitrarily for any proposal.

#### Executing Governance Actions

**Required env vars:**

- `GOVERNANCE_ADDRESS`: address of OD Governance
- `JSON_FILE_PATH`: the path to the desired JSON proposal file
- `GOV_EXECUTOR_PK`: the private key of the executor of the governance action

[`ExecuteProposal.s.sol`](script/gov/ExecuteProposal.s.sol) is used to execute a proposal given the path of the JSON file you want, e.g. `export JSON_FILE_PATH=gov-output/1-add-collateral-proposal.json`.

The script extracts the necessary execution params from the JSON-the same params used during the proposal and executes the proposal. This script can be used arbitrarily for any proposal.
