// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {ChainlinkRelayerChild} from '@contracts/factories/ChainlinkRelayerChild.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IChainlinkOracle mockPriceFeed = IChainlinkOracle(mockContract('ChainlinkPriceFeed'));
  IChainlinkOracle mockSequencerUptimeFeed = IChainlinkOracle(mockContract('ChainlinkSequencerUptimeFeed'));

  ChainlinkRelayerFactory chainlinkRelayerFactory;
  ChainlinkRelayerChild chainlinkRelayerChild = ChainlinkRelayerChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'ChainlinkRelayerChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    chainlinkRelayerFactory = new ChainlinkRelayerFactory(address(mockSequencerUptimeFeed));
    label(address(chainlinkRelayerFactory), 'ChainlinkRelayerFactory');

    chainlinkRelayerFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockDecimals(uint8 _decimals) internal {
    vm.mockCall(address(mockPriceFeed), abi.encodeCall(mockPriceFeed.decimals, ()), abi.encode(_decimals));
  }

  function _mockDescription(string memory _description) internal {
    vm.mockCall(address(mockPriceFeed), abi.encodeCall(mockPriceFeed.description, ()), abi.encode(_description));
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

    new ChainlinkRelayerFactory(address(mockSequencerUptimeFeed));
  }

  function test_Set_SequencerUptimeFeed() public happyPath {
    assertEq(address(chainlinkRelayerFactory.sequencerUptimeFeed()), address(mockSequencerUptimeFeed));
  }

  function test_Revert_NullSequencerUptimeFeed() public happyPath {
    vm.expectRevert(IChainlinkRelayerFactory.ChainlinkRelayerFactory_NullSequencerUptimeFeed.selector);

    new ChainlinkRelayerFactory(address(0));
  }
}

contract Unit_ChainlinkRelayerFactory_DeployChainlinkRelayer is Base {
  event NewChainlinkRelayer(
    address indexed _chainlinkRelayer, address _priceFeed, address _sequencerUptimeFeed, uint256 _staleThreshold
  );

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

    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockPriceFeed), _staleThreshold);
  }

  function test_Deploy_ChainlinkRelayerChild(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockPriceFeed), _staleThreshold);

    assertEq(address(chainlinkRelayerChild).code, type(ChainlinkRelayerChild).runtimeCode);

    // params
    assertEq(address(chainlinkRelayerChild.priceFeed()), address(mockPriceFeed));
    assertEq(address(chainlinkRelayerChild.sequencerUptimeFeed()), address(mockSequencerUptimeFeed));
    assertEq(chainlinkRelayerChild.staleThreshold(), _staleThreshold);
  }

  function test_Set_ChainlinkRelayers(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockPriceFeed), _staleThreshold);

    assertEq(chainlinkRelayerFactory.chainlinkRelayersList()[0], address(chainlinkRelayerChild));
  }

  function test_Emit_NewChainlinkRelayer(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    vm.expectEmit();
    emit NewChainlinkRelayer(
      address(chainlinkRelayerChild), address(mockPriceFeed), address(mockSequencerUptimeFeed), _staleThreshold
    );

    chainlinkRelayerFactory.deployChainlinkRelayer(address(mockPriceFeed), _staleThreshold);
  }

  function test_Return_ChainlinkRelayer(
    uint256 _staleThreshold,
    uint8 _decimals,
    string memory _description
  ) public happyPath(_staleThreshold, _decimals, _description) {
    assertEq(
      address(chainlinkRelayerFactory.deployChainlinkRelayer(address(mockPriceFeed), _staleThreshold)),
      address(chainlinkRelayerChild)
    );
  }
}

contract Unit_ChainlinkRelayerFactory_SetSequencerUptimeFeed is Base {
  modifier happyPath(address _sequencerUptimeFeed) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_sequencerUptimeFeed);
    _;
  }

  function _assumeHappyPath(address _sequencerUptimeFeed) internal pure {
    vm.assume(_sequencerUptimeFeed != address(0));
  }

  function test_Revert_Unauthorized(address _sequencerUptimeFeed) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    chainlinkRelayerFactory.setSequencerUptimeFeed(_sequencerUptimeFeed);
  }

  function test_Revert_NullSequencerUptimeFeed() public {
    vm.startPrank(authorizedAccount);
    vm.expectRevert(IChainlinkRelayerFactory.ChainlinkRelayerFactory_NullSequencerUptimeFeed.selector);

    chainlinkRelayerFactory.setSequencerUptimeFeed(address(0));
  }

  function test_Set_SequencerUptimeFeed(address _sequencerUptimeFeed) public happyPath(_sequencerUptimeFeed) {
    chainlinkRelayerFactory.setSequencerUptimeFeed(_sequencerUptimeFeed);

    assertEq(address(chainlinkRelayerFactory.sequencerUptimeFeed()), _sequencerUptimeFeed);
  }
}
