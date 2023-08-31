# Modifiable

See [Modifiable.sol](/src/contracts/utils/Modifiable.sol/abstract.Modifiable.html) for more details.

## 1. Introduction

This abstract contract establishes a standardized mechanism by which contracts can modify their registry and parameters. The available methods are confined to authorized accounts, ensuring that only designated entities have the authority to make these adjustments.

## 2. Contract Details

### Key Methods:

- `modifyParameters`: Modifies a parameter of the contract.
- `_validateParameters`: Hook to validate the parameters after modifying them.

## 3. Key Mechanisms & Concepts

### Standarized Method

The `modifyParameters` method is standarized to be shared across contracts that may require different types of parameters. The parameter values are passed as a bytes array, and the inheriting contract is responsible for parsing them (see [Encoding](/src/libraries/Encoding.sol/library.Encoding.html)).

There are 2 methods that can be used to modify the parameters:

- `modifyParameters(bytes32 _param, bytes memory _data)`: Modifies a global contract parameter.
- `modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data)`: Modifies a contract per-collateral parameter.

### Parameters Structs

To explicitly define the parameters that can be modified, the contracts should define a parameters struct. Contract parameters that can be modified should be accessed through this struct, and will be read either as `params.__param__` or `cParams[_cType].__param__`.

### Parameters Validation

The `_validateParameters` hook is called after modifying the parameters, and can be used to validate the new parameters according to the contract's logic. All contract parameters should be validated, despite they having been modified or not. Common validations may use some of the methods defined in the [Assertions](/src/libraries/Assertions.sol/library.Assertions.html) library.

As with the `modifyParameters` method, there are 2 methods that can be used to validate the parameters:

- `_validateParameters`: Validates all global contract parameter.
- `_validateCParameters`: Validates all contract per-collateral parameter.

> **Notice**: The validation hooks should avoid a parameter that would cause the contract to be set in an undesired way. For example, the OracleRelayer contract implements a check on the liquidation ratio to be always above 100%, else the system would allow for overleveraged positions.

## 4. Gotchas

### Constructors

Contracts that incorporate this functionality must guarantee that their constructors enforce initial parameter validation. This approach serves to prevent the deployment of contracts with invalid parameters. As a result, all validated parameters must be provided as arguments during the contract's construction, ensuring that only valid configurations are utilized upon deployment.

### Testing

To thoroughly test the complete implementation of the `modifyParameters` method, the testing process should involve fuzzing a parameters struct with all potential values. Subsequently, the method should be called, and the outcome must be validated to confirm that all parameters within the struct have been altered as intended.

To achieve this testing goal, the approach involves comparing the hash of the modified parameters struct with the struct's state obtained from the contract after the modifications have been executed. This rigorous comparison ensures that the method successfully and accurately modifies each parameter as specified.

## 5. Failure Modes
