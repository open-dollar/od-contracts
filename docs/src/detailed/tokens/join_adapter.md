# Join Adapters

See [CoinJoin.sol](/src/contracts/utils/CoinJoin.sol/contract.CoinJoin.html), [CollateralJoin.sol](/src/contracts/utils/CollateralJoin.sol/contract.CollateralJoin.html) for more details.

## 1. Introduction

The Join Adapter contracts assume responsibility for facilitating the seamless movement of collateral and system coin ERC20s into and out of the system. Their functions encompass:

- Safeguarding collateral ERC20 tokens through locking them within the contract, leading to an augmentation of the user's collateral type balance.
- Liberating collateral ERC20 tokens back to the user, thereby diminishing the user's collateral type balance.
- Generating system coin ERC20 tokens through the locking of internal coins within the contract.
- Eradicating system coin ERC20 tokens from the user's holdings, resulting in the release of internal coins to the user.

These contracts engage directly with the SAFE Engine, necessitating occasional user approval to permit the contract to access funds from their account. In the system, a collateral balance is denoted by a specific collateral type string (for example, 'ETH-A', 'OP').

## 2. Contract Details

## 2.1 Collateral Join

### Key Methods:

- `join`: This operation secures collateral ERC20 tokens within the contract and augments the collateral type balance of the designated account.
- `exit`: This function liberates collateral ERC20 tokens to the specified account, resulting in a reduction of the user's collateral type balance.

## 2.2 Coin Join

### Key Methods:

- `exit`: This action involves locking internal coins within the contract and generating system coin ERC20 tokens for the designated account.
- `join`: This function entails releasing internal coins to the specified account while extinguishing system coin ERC20 tokens from the user's holdings.

## 3. Key Mechanisms & Concepts

### System Coin vs Collateral Modes

The system coin ERC20 represents a transferable unit of internal COINs that were initially generated via SAFEs. The ultimate purpose of the system coin ERC20 is to integrate into the system and contribute to the reduction of DEBT. This purpose leads to a reversal in logic between the Coin and Collateral Join contracts concerning the `join` and `exit` methods.

In the Collateral Join contract, users lock collateral to create an internal balance of a specific collateral type, and they can subsequently burn this internal balance to retrieve their ERC20 tokens. Conversely, in the Coin Join contract, users perform the opposite actions: they burn or mint the system coin ERC20 to respectively release or lock internal coins.

### ERC20 Decimal Conversion

To accommodate a diverse array of collaterals and price references, the system employs a standardized unit for establishing balances and quotes, utilizing WAD precision (18 decimals). To ensure this consistency, the Collateral Join contract integrates a conversion factor during the execution of its join and exit methods. This strategy guarantees that users consistently interact with the contract using `wei` measurements, which align with the token's inherent precision.

**Notice**: The CollateralJoin contract supports tokens with less than 18 decimals, but not more.

## 4. Gotchas

### Precision Dust

Due to the potential variance between the precision of the system and that of the ERC20 tokens, users might encounter a situation where their collateral balance is lower than the system's minimum withdrawal threshold. This discrepancy can arise when the amount of collateral falls short of even `1 wei`, which is the smallest unit the system can process for withdrawal purposes.

## 5. Failure Modes

### Global Settlement Mode

When the Coin Join functionality is deactivated, the contract permits the use of the `join` method while restricting access to the `exit` method. This implies that users retain the ability to convert their system coin ERC20 into internal coins, but they are prevented from generating additional system coin ERC20 tokens.

Conversely, in the event of Collateral Join being disabled, the contract enables the `exit` method while prohibiting the use of the `join` method. This signifies that users maintain the capability to redeem their collateral ERC20 by burning their corresponding collateral type balance, but they are unable to add more collateral ERC20 tokens to the contract.

### On Authorizations

- For Coin Join to mint system coin ERC20, authorization within the System Coin contract is mandatory.
- Prior to interaction, users are required to grant approval within the SAFE Engine for the Coin Join contracts to access and withdraw funds from their account.
- Collateral Join necessitates authorization within the SAFE Engine contract for the purpose of modifying the collateral balance.
- With an active ERC20 balance and SAFE Engine authorization, the Collateral Join contract is capable of withdrawing funds from the user's account.
- The Coin Join contract can effectively burn system coin ERC20 tokens to provide funds to the user's account, provided the user has granted approval within the SAFE Engine and the Coin Join retains an internal coin balance.

### Replaceability

Both the Coin and Collateral Join contracts could potentially be superseded by a single new contract through a multi-step process carried out by a single user. This process involves repeating the following sequence:

1. Deploy and configure the new Join contract.
2. Deactivate the current Join contract.
3. For the Collateral Join:
   - Execute `exit` on the old (deactivated) contract (reducing the internal balance).
   - Execute `join` on the new contract (increasing the internal balance).
   - Execute `exit` on the old contract.
   - Repeat this sequence until all collateral is successfully transferred.
4. For the Coin Join:
   - Remove authorization for the system coin ERC20 from the old contract.
   - Execute `join` on the old (deactivated) contract (increasing the internal balance).
   - Execute `exit` on the new contract (reducing the internal balance).
   - Repeat this sequence until all system coin ERC20 tokens are moved.

The primary objective of this procedure is to ensure that both contracts conclude with no funds remaining locked within them. This approach guarantees that the new join contract attains an internal balance equivalent to the amount of ERC20 tokens locked. Subsequently, it's essential to revoke the relevant authorizations from these contracts to complete their deprecation.
