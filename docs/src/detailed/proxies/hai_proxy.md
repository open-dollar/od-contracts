# HAI Proxy

See [ODProxy.sol](/src/contracts/proxies/ODProxy.sol/contract.ODProxy.html) for more details.

## 1. Introduction

The HAI Proxy contract is a powerful and flexible smart contract commonly used within the decentralized finance (DeFi) ecosystem. Its primary function is to act as an extensible, personal proxy contract that allows users to bundle multiple actions into single, atomic transactions. With HAI Proxy, users can interact with multiple smart contracts or execute complex contract calls in a secure, efficient, and modular manner.

## 2. Contract Details

### Key Methods:

**Owner**

- `execute`: Allows owner to call a specific contract (usually a library or helper contract containing business logic) and pass in encoded function arguments to execute a certain operation.

## 3. Key Mechanisms & Concepts

### Delegate Calls

In the Ethereum smart contract ecosystem, a delegate call is a special type of contract invocation that allows one contract to "borrow" code from another contract, executing it as if it were part of the calling contract's own code. Unlike a regular function call, a delegate call operates within the context of the calling contract, meaning it can read and modify the calling contract's state variables.

## 4. Gotchas

### Dealing with Delegate Calls and ERC20 Transfers

When using proxy contracts that rely on delegate calls, certain common actions like ERC20 token transfers require special handling. In a typical setup, if a user attempts to execute `ERC20.transfer` directly, aiming to transfer a balance that is attributed to the proxy, the operation will fail and the call will revert. This is because delegate calls operate in the context of the calling contract, not the called contract. In this case, the calling contract is the proxy, which doesn't hold the tokens, leading to a failed transaction.

To work around this issue, an intermediary contract can be introduced. This intermediary contract is responsible for parsing the intended action and then executing the `transfer` operation using a regular call, rather than a delegate call.

## 5. Failure Modes
