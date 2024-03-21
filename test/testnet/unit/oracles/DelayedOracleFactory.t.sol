// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {DelayedOracleFactory} from '@contracts/factories/DelayedOracleFactory.sol';
import {DelayedOracleChild, DelayedOracle} from '@contracts/factories/DelayedOracleChild.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ODTest, stdStorage, StdStorage} from '@testnet/utils/ODTest.t.sol';

import 'forge-std/console2.sol';
import '@contracts/oracles/DenominatedOracle.sol';

contract PriceSourceMock is IBaseOracle {
  function symbol() external view override returns (string memory) {
    return 'ETH/USD';
  }

  function getResultWithValidity() external view override returns (uint256, bool) {
    return (1000, true);
  }

  function read() external view override returns (uint256) {
    return 1000;
  }
}

abstract contract Base is ODTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IBaseOracle mockPriceSource = IBaseOracle(mockContract('PriceSource'));

  DelayedOracleFactory delayedOracleFactory;
  DelayedOracleChild delayedOracleChild = DelayedOracleChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'DelayedOracleChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    delayedOracleFactory = new DelayedOracleFactory();
    label(address(delayedOracleFactory), 'DelayedOracleFactory');

    delayedOracleFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockSymbol(string memory _symbol) internal {
    vm.mockCall(address(mockPriceSource), abi.encodeCall(mockPriceSource.symbol, ()), abi.encode(_symbol));
  }

  function _mockGetResultWithValidity(uint256 _result, bool _validity) internal {
    vm.mockCall(
      address(mockPriceSource),
      abi.encodeCall(mockPriceSource.getResultWithValidity, ()),
      abi.encode(_result, _validity)
    );
  }
}

contract Unit_DelayedOracleFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    delayedOracleFactory = new DelayedOracleFactory();
  }
}

contract Unit_DelayedOracleFactory_DeployDelayedOracle is Base {
  event NewDelayedOracle(address indexed _delayedOracle, address _priceSource, uint256 _updateDelay);

  modifier happyPath(uint256 _updateDelay, string memory _symbol, uint256 _result, bool _validity) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_updateDelay);
    _mockValues(_symbol, _result, _validity);
    _;
  }

  function _assumeHappyPath(uint256 _updateDelay) internal pure {
    vm.assume(_updateDelay != 0);
  }

  function _mockValues(string memory _symbol, uint256 _result, bool _validity) internal {
    _mockSymbol(_symbol);
    _mockGetResultWithValidity(_result, _validity);
  }

  function test_Revert_Unauthorized(uint256 _updateDelay) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    delayedOracleFactory.deployDelayedOracle(mockPriceSource, _updateDelay);
  }

  function test_Deploy_DelayedOracleChild(
    uint256 _updateDelay,
    string memory _symbol,
    uint256 _result,
    bool _validity
  ) public happyPath(_updateDelay, _symbol, _result, _validity) {
    delayedOracleFactory.deployDelayedOracle(mockPriceSource, _updateDelay);

    assertEq(address(delayedOracleChild).code, type(DelayedOracleChild).runtimeCode);

    // params
    assertEq(address(delayedOracleChild.priceSource()), address(mockPriceSource));
    assertEq(delayedOracleChild.updateDelay(), _updateDelay);
  }

  function test_Set_DelayedOracles(
    uint256 _updateDelay,
    string memory _symbol,
    uint256 _result,
    bool _validity
  ) public happyPath(_updateDelay, _symbol, _result, _validity) {
    delayedOracleFactory.deployDelayedOracle(mockPriceSource, _updateDelay);

    assertEq(delayedOracleFactory.delayedOraclesList()[0], address(delayedOracleChild));
  }

  function test_Emit_NewDelayedOracle(
    uint256 _updateDelay,
    string memory _symbol,
    uint256 _result,
    bool _validity
  ) public happyPath(_updateDelay, _symbol, _result, _validity) {
    vm.expectEmit();
    emit NewDelayedOracle(address(delayedOracleChild), address(mockPriceSource), _updateDelay);

    delayedOracleFactory.deployDelayedOracle(mockPriceSource, _updateDelay);
  }

  function test_Return_DelayedOracle(
    uint256 _updateDelay,
    string memory _symbol,
    uint256 _result,
    bool _validity
  ) public happyPath(_updateDelay, _symbol, _result, _validity) {
    assertEq(
      address(delayedOracleFactory.deployDelayedOracle(mockPriceSource, _updateDelay)), address(delayedOracleChild)
    );
  }

  function test_ShouldUpate() public {
    PriceSourceMock priceSource = new PriceSourceMock();
    DelayedOracle oracle = new DelayedOracle(priceSource, 100);
    assertTrue(!oracle.shouldUpdate());
    vm.expectRevert(IDelayedOracle.DelayedOracle_DelayHasNotElapsed.selector);
    oracle.updateResult();
  }

  function test_inversed() public {
    PriceSourceMock priceSource = new PriceSourceMock();
    DenominatedOracle oracle = new DenominatedOracle(priceSource, priceSource, true);
    // mock results, we just care if call can go through
    (uint256 _result, bool _validity) = oracle.getResultWithValidity();
  }
}
