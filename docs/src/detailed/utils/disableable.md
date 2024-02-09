# Disableable

See [Disableable.sol](/src/contracts/utils/Disableable.sol/abstract.Disableable.html) for more details.

## 1. Introduction

This abstract contract introduces a fundamental disable mechanism for contracts. It grants the ability for a contract to be effectively deactivated, and utilizes modifiers to control access to specific methods based on the contract's current state.

## 2. Contract Details

### Key Methods:

**Authorized**
- `disableContract`: Disables the contract.

**Internal**
- `_onContractDisable`: Hook to be called when the contract is disabled.
- `_isEnabled`: Checks if the contract is enabled.
  
**Modifiers**
- `whenEnabled`: Restricts access to the method to when the contract is enabled.
- `whenDisabled`: Restricts access to the method to when the contract is disabled.

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
