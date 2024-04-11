// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import '@contracts/factories/ODCreate2Factory.sol';

contract DeployContractMock {
  function test() public returns (bool) {
    return true;
  }
}

contract ODCreate2FactoryTest is Test {
  ODCreate2Factory factory;
  address deployer = address(0x01);

  function setUp() public virtual {
    factory = new ODCreate2Factory(deployer);
  }

  function testPrecomputeAddress() public {
    bytes32 salt = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    bytes32 initCodeHash = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    address precompute = factory.precomputeAddress(salt, initCodeHash);
    assertEq(
      precompute, address(uint160(uint256(keccak256(abi.encodePacked(hex'ff', address(factory), salt, initCodeHash)))))
    );
  }

  function testDeploymentOfMockContract() public {
    bytes32 salt = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    bytes memory initCode = type(DeployContractMock).creationCode;
    address deployment = factory.create2deploy(salt, initCode);
    assertEq(
      deployment,
      address(uint160(uint256(keccak256(abi.encodePacked(hex'ff', address(factory), salt, keccak256(initCode))))))
    );
    (bool success, bytes memory data) = deployment.call(abi.encodeWithSignature('test()'));
    assert(success);
    assertEq(abi.decode(data, (bool)), true);
  }
}
