// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {ChainlinkRelayerChild} from '@contracts/factories/ChainlinkRelayerChild.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IChainlinkOracle mockChainlinkFeed = IChainlinkOracle(mockContract('ChainlinkOracle'));

  ChainlinkRelayerFactory chainlinkRelayerFactory;
  ChainlinkRelayerChild chainlinkRelayerChild = ChainlinkRelayerChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'ChainlinkRelayerChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    chainlinkRelayerFactory = new ChainlinkRelayerFactory();
    label(address(chainlinkRelayerFactory), 'ChainlinkRelayerFactory');

    chainlinkRelayerFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockDecimals(uint8 _decimals) internal {
    vm.mockCall(address(mockChainlinkFeed), abi.encodeCall(mockChainlinkFeed.decimals, ()), abi.encode(_decimals));
  }

  function _mockDescription(string memory _description) internal {
    vm.mockCall(address(mockChainlinkFeed), abi.encodeCall(mockChainlinkFeed.description, ()), abi.encode(_description));
  }
}

contract Unit_ChainlinkRelayerFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    chainlinkRelayerFactory = new ChainlinkRelayerFactory();
  }
}

contract Unit_ChainlinkRelayerFactory_DeployChainlinkRelayer is Base {
  event NewChainlinkRelayer(address indexed _chainlinkRelayer, address _aggregator, uint256 _staleThreshold);

  modifier happyPath(uint256 _staleThreshold, uint8 _decimals, string memory _description) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_staleThreshold, _decimals);
    _mockValues(_decimals, _description);
    _;
  }

  function _assumeHappyPath(uint256 _staleThreshold, uint8 _decimals) internal pure {
    vm.assume(_staleThreshold != 0);
    vm.assume(_decimals <= 18);
  }

  function _mockValues(uint8 _decimals, string memory _description) internal {
    _mockDecimals(_decimals);
    _mockDescription(_description);
  }

  function test_Revert_Unauthorized(uint256 _staleThreshold) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockChainlinkFeed), _staleThreshold);
  }

  function test_Deploy_ChainlinkRelayerChild(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockChainlinkFeed), _staleThreshold);

    assertEq(address(chainlinkRelayerChild).code, type(ChainlinkRelayerChild).runtimeCode);

    // params
    assertEq(address(chainlinkRelayerChild.chainlinkFeed()), address(mockChainlinkFeed));
    assertEq(chainlinkRelayerChild.staleThreshold(), _staleThreshold);
  }

  function test_Set_ChainlinkRelayers(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockChainlinkFeed), _staleThreshold);

    assertEq(chainlinkRelayerFactory.chainlinkRelayersList()[0], address(chainlinkRelayerChild));
  }

  function test_Emit_NewChainlinkRelayer(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    vm.expectEmit();
    emit NewChainlinkRelayer(address(chainlinkRelayerChild), address(mockChainlinkFeed), _staleThreshold);

    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockChainlinkFeed), _staleThreshold);
  }

  function test_Return_ChainlinkRelayer(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    assertEq(
      address(chainlinkRelayerFactory.deployChainlinkRelayer(address(mockChainlinkFeed), _staleThreshold)),
      address(chainlinkRelayerChild)
    );
  }
}
