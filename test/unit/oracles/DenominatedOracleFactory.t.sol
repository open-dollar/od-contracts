// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {DenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {DenominatedOracleChild} from '@contracts/factories/DenominatedOracleChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IBaseOracle mockPriceSource = IBaseOracle(mockContract('PriceSource'));
  IBaseOracle mockDenominationPriceSource = IBaseOracle(mockContract('DenominationPriceSource'));

  DenominatedOracleFactory denominatedOracleFactory;
  DenominatedOracleChild denominatedOracleChild = DenominatedOracleChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'DenominatedOracleChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    denominatedOracleFactory = new DenominatedOracleFactory();
    label(address(denominatedOracleFactory), 'DenominatedOracleFactory');

    denominatedOracleFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockSymbol(string memory _symbol) internal {
    vm.mockCall(address(mockPriceSource), abi.encodeCall(mockPriceSource.symbol, ()), abi.encode(_symbol));
    vm.mockCall(
      address(mockDenominationPriceSource), abi.encodeCall(mockDenominationPriceSource.symbol, ()), abi.encode(_symbol)
    );
  }
}

contract Unit_DenominatedOracleFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new DenominatedOracleFactory();
  }
}

contract Unit_DenominatedOracleFactory_DeployDenominatedOracle is Base {
  event NewDenominatedOracle(
    address indexed _denominatedOracle, address _priceSource, address _denominationPriceSource, bool _inverted
  );

  modifier happyPath(string memory _symbol) {
    vm.startPrank(authorizedAccount);

    _mockValues(_symbol);
    _;
  }

  function _mockValues(string memory _symbol) internal {
    _mockSymbol(_symbol);
  }

  function test_Revert_Unauthorized(bool _inverted) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    denominatedOracleFactory.deployDenominatedOracle(mockPriceSource, mockDenominationPriceSource, _inverted);
  }

  function test_Deploy_DenominatedOracleChild(bool _inverted, string memory _symbol) public happyPath(_symbol) {
    denominatedOracleFactory.deployDenominatedOracle(mockPriceSource, mockDenominationPriceSource, _inverted);

    assertEq(address(denominatedOracleChild).code, type(DenominatedOracleChild).runtimeCode);

    // params
    assertEq(address(denominatedOracleChild.priceSource()), address(mockPriceSource));
    assertEq(address(denominatedOracleChild.denominationPriceSource()), address(mockDenominationPriceSource));
    assertEq(denominatedOracleChild.inverted(), _inverted);
  }

  function test_Set_DenominatedOracles(bool _inverted, string memory _symbol) public happyPath(_symbol) {
    denominatedOracleFactory.deployDenominatedOracle(mockPriceSource, mockDenominationPriceSource, _inverted);

    assertEq(denominatedOracleFactory.denominatedOraclesList()[0], address(denominatedOracleChild));
  }

  function test_Emit_NewDenominatedOracle(bool _inverted, string memory _symbol) public happyPath(_symbol) {
    vm.expectEmit();
    emit NewDenominatedOracle(
      address(denominatedOracleChild), address(mockPriceSource), address(mockDenominationPriceSource), _inverted
    );

    denominatedOracleFactory.deployDenominatedOracle(mockPriceSource, mockDenominationPriceSource, _inverted);
  }

  function test_Return_DenominatedOracle(bool _inverted, string memory _symbol) public happyPath(_symbol) {
    assertEq(
      address(denominatedOracleFactory.deployDenominatedOracle(mockPriceSource, mockDenominationPriceSource, _inverted)),
      address(denominatedOracleChild)
    );
  }
}
