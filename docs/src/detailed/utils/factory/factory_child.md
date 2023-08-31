# FactoryChild

See [FactoryChild.sol](/src/contracts/factories/FactoryChild.sol/abstract.FactoryChild.html) for more details.

## 1. Introduction

This abstract contract is inherited by all contracts that are deployed through a factory. It provides a reference to the parent factory.

## 2. Contract Details

### Key Methods:

- `factory`: Returns the parent factory.

## 3. Key Mechanisms & Concepts

The rationale behind this contract is to provide a way of extending contracts that are standalone deployable, to be deployed through a factory. Contracts that are factory deployed can also implement other factory related utils, such as [AuthorizableChild](authorizable_child.md) or [DisableableChild](disableable_child.md).

## 4. Gotchas

### Constructors

Contracts which only change from the standalone version is the constructor routine should not create a new instance of the contract, but be considered as another child implementation of the same contract. This is the case of the [CollateralJoinDelegatableChild](/src/contracts/factories/CollateralJoinDelegatableChild.sol/contract.CollateralJoinDelegatableChild.html), which is a child implementation of the CollateralJoin contract, that calls the `ERC20Votes.delegate` method on constructor.

## 5. Failure Modes
