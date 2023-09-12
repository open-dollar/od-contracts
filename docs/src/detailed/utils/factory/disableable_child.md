# DisableableChild

See [DisableableChild.sol](/src/contracts/factories/DisableableChild.sol/abstract.DisableableChild.html) for more details.

## 1. Introduction

This abstract contract extends the [Disableable](/detailed/utils/disableable.md) contract for factory deployed instances, to allow for the parent factory to be disabled, and extend the disabled state to all the child contracts.

## 2. Contract Details

**Overrides**

- `_isEnabled`: internal method to check if the contract AND the parent factory are enabled.
- `_onContractDisable`: can only be called by the parent factory.

## 3. Key Mechanisms & Concepts

The contract will check if the contract AND the parent factory are enabled. If either is disabled, the contract is considered disabled.

## 4. Gotchas

Contracts that inherit this contract can only be disabled by the parent factory. In that way, the factory can keep track of all the enabled contracts that have been deployed through it.

## 5. Failure Modes
