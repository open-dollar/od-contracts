# Authorizable

See [Authorizable.sol](/src/contracts/utils/Authorizable.sol/abstract.Authorizable.html) for more details.

## 1. Introduction

This abstract contract introduces a fundamental authorization mechanism designed for contracts. It enables a contract to manage authorization for multiple accounts, granting them specific permissions. This is achieved through the use of modifiers, which serve to control and restrict access to designated methods as required.

## 2. Contract Details

### Key Methods:

**Authorized**

- `addAuthorization`: Grants authorization to an account.
- `removeAuthorization`: Removes authorization from an account.

**Notice**: Both methods will revert in the case of a no-operation (i.e. the account is already authorized or unauthorized).

## 3. Key Mechanisms & Concepts

In the contracts that inherit this functionality, all authorized accounts possess equal access privileges, without any hierarchy of authorization. This implies that any authorized account is capable of both adding and removing authorization for any other account.

## 4. Gotchas

## 5. Failure Modes
