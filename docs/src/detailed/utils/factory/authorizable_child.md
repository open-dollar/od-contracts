# AuthorizableChild

See [AuthorizableChild.sol](/src/contracts/factories/AuthorizableChild.sol/abstract.AuthorizableChild.md) for more details.

## 1. Introduction

This abstract contract extends the [Authorizable](/detailed/utils/authorizable.md) contract for factory deployed instances, to allow for a contract to be authorized in the parent factory, and still be able to access restricted methods.

## 2. Contract Details

**Overrides**

- `_isAuthorized`: internal method to check if the sender is authorized in the contract or the parent factory.

## 3. Key Mechanisms & Concepts

The contract will check if the sender is authorized in the contract or the parent factory.

## 4. Gotchas

## 5. Failure Modes
