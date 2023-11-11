# SAFE Manager

See [HaiSafeManager.sol](/src/contracts/proxies/HaiSafeManager.sol/contract.HaiSafeManager.html) and [SAFEHandler.sol](/src/contracts/proxies/SAFEHandler.sol/contract.SAFEHandler.html) for more details.

## 1. Introduction

The SAFE Manager Contract serves as an interface for interacting with the SAFE Engine, which is the core contract responsible for managing SAFEs in the HAI ecosystem. While the SAFE Engine handles the intricate logic and state changes for SAFEs, the SAFE Manager simplifies and streamlines user interactions with their SAFEs. Essentially, it provides an abstraction layer that facilitates operations such as depositing collateral, withdrawing, and managing debt positions in a user-friendly manner.

## 2. Contract Details

### Key Methods:

- `openSAFE`: Deploys a new SAFE Handler contract and registers it in the SAFE Manager.
- `transferSAFEOwnership`: Initiates the ownership transfer of a SAFE to another address (doesn't reset SAFE protection).
- `acceptSAFEOwnership`: Commits to the ownership transfer of a SAFE to another address (needs to be called by the new SAFE owner).
- `modifySAFECollateralization`: Modifies the collateralization ratio of a SAFE (lock/free collateral and/or generate/repay debt).
- `transferCollateral`: Transfers collateral from one account to another.
- `transferInternalCoins`: Transfers internal coins from one account to another.
- `quitSystem`: Closes a SAFE and transfers all remaining collateral and debt to the user's address.
- `enterSystem`: Migrates collateral and debt from a source SAFE Handler to a destination SAFE.
- `moveSAFE`: Migrates a SAFE from one SAFE to another.
- `protectSAFE`: Protects a SAFE from being liquidated, using a SafeSaviour position to improve the SAFE health when it falls below the liquidation ratio.

## 3. Key Mechanisms & Concepts

### SAFE IDs

The SAFE Engine identifies each SAFE by its unique contract address and the type of collateral it holds. In contrast, the SAFE Manager simplifies this by assigning each SAFE an auto-incremental ID when it is created. This ID serves as an easy-to-use reference point for users and external contracts, streamlining interactions and management. The auto-incremental ID is particularly useful for human readability and ease of interaction, while the address and collateral type identification in the SAFE Engine provides more granularity and is essential for the underlying mechanics.

### Understanding the SAFE Handler

The SAFE Handler is a specialized contract that acts as an intermediary between the SAFE Engine and the SAFE Manager in the HAI system. Spawned when a new SAFE is created from the SAFE Manager, this contract communicates directly with the SAFE Engine from its unique address, to grant the SAFE Manager authorization to manage its corresponding SAFE, allowing for simplified user interactions and enhanced security. Essentially, each SAFE Handler represents a single-collateral SAFE and is managed by the SAFE Manager, which also controls any further authorizations for it.

### User Authorization

The SAFE Manager Contract allows users to specify which addresses are authorized to interact with their SAFEs. This is crucial for advanced users who may want to deploy automated strategies via external smart contracts or trusted third parties.

### SAFE Ownership Transfer

One unique feature is the ability to transfer ownership of a SAFE to another address. This facilitates a range of possibilities, including the sale of debt positions or the use of SAFEs in more complex financial products.

By providing a more accessible interface to the underlying SAFE Engine, the SAFE Manager Contract is an essential tool for anyone looking to interact with SAFEs in the HAI ecosystem.

### SAFE Protection

SAFE owners can choose to connect a SafeSaviour position in order to improve the SAFE health and protect it from liquidation. When the SAFE is on the process of being liquidated, the SafeSaviour contract will unwind the user's position, in order to either reduce the SAFE debt, or increase its collateral, to improve the SAFE health and try to prevent liquidation.

SAFE owners need to account that the SafeSaviour position is connected to the SAFE id, so when transferring ownership to another account, it is responsibility of the previous owner to disconnect any liquidity deposited in the SafeSaviour contract.

## 4. Gotchas

## 5. Failure Modes
