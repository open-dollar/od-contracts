# Basic Actions

See [BasicActions.sol](/src/contracts/proxies/actions/BasicActions.sol/contract.BasicActions.html) for more details.

## 1. Introduction

These actions encapsulate all functionalities needed for the comprehensive management of Single-Collateral SAFEs within the SAFE Engine. Whether you're aiming to open, modify, or close SAFEs, Basic Actions provide the modular and gas-efficient methods to achieve your goals.

The scope of these Actions is to provide the user with a set of methods to interact with the SAFE Manager Contract. These methods are used by the HAI Proxy contract to execute the corresponding operations on the SAFE Engine.

## 2. Contract Details

### Key Methods:

- `openSAFE`: Creates a new SAFEHandler (associated with a collateral type) and registers it in the SAFE Manager.
- `generateDebt`: Generates debt within a SAFE and transfers the generated coins to the user's address.
- `lockTokenCollateral`: Locks a certain amount of tokens as collateral within a SAFE.
- `freeTokenCollateral`: Frees a certain amount of tokens from a SAFE's collateral, and transfers them to the user's address.
- `repayAllDebt`: Repays all debt within a SAFE (the amount of debt to repay is automatically calculated).

## 3. Key Mechanisms & Concepts

### Key Concepts for SAFE Management

Managing Single-Collateral SAFEs involves a series of actions to effectively handle your collateral and debt. In this context, four core concepts—Lock, Free, Collect, and Exit—play a pivotal role. These actions are integrated into the Basic Actions module, simplifying the interaction with the SAFE Manager Contract and the SAFE Engine. Here's a closer look at each:

- **LOCK**: Deposit collateral into a specified SAFE. This effectively "locks" your assets within the SAFE, providing the foundation upon which you can draw debt. It's the starting point for leveraging your assets within the SAFE ecosystem.
- **FREE**: The inverse of "Lock." It lets you withdraw or "release" collateral from a SAFE back to your designated address, given that you meet the SAFE's conditions (e.g., maintaining a specific collateral ratio).
- **COLLECT**: The "Collect" action is used to transfer collateral from an external address into the proxy contract. This is generally a preparatory step for other actions, such as "Lock," where the collateral will be moved from the proxy to the SAFE.
- **EXIT**: The "Exit" action allows you to burn the internal representation of collateral in exchange for ERC20 tokens, which are transferred to your own address. This action is often used when you wish to exit the SAFE ecosystem and convert your assets back to a fungible, transferable form.

## 4. Gotchas

### Internal Balances of the User

In proxy-based systems designed for asset management, the internal balances within the proxy contract are often automatically reset to zero after each transaction. This is because actions are configured to "exit" or transfer any remaining coins or tokens back to the user's own wallet. The design serves dual purposes: it enhances security by not leaving residual assets exposed in the proxy contract, and it simplifies user experience by allowing users to see their complete asset balances directly in their own accounts. Thus, if you observe that the internal balances of your proxy contract are consistently zero, it's because the system is purposefully designed to "exit" any remaining assets, ensuring that no residual value is left lingering within the proxy.

## 5. Failure Modes
