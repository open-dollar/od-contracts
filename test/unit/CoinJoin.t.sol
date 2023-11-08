// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CoinJoinForTest} from '@test/mocks/CoinJoinForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {RAY} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  ISystemCoin mockSystemCoin = ISystemCoin(mockContract('SystemCoin'));

  CoinJoinForTest coinJoin;

  function setUp() public virtual {
    vm.startPrank(deployer);

    coinJoin = new CoinJoinForTest(address(mockSafeEngine), address(mockSystemCoin));
    label(address(coinJoin), 'CoinJoin');

    coinJoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    coinJoin.setContractEnabled(_contractEnabled);
  }
}

contract Unit_CoinJoin_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    coinJoin = new CoinJoinForTest(address(mockSafeEngine), address(mockSystemCoin));
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(coinJoin.contractEnabled(), true);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    vm.assume(_safeEngine != address(0));
    coinJoin = new CoinJoinForTest(_safeEngine, address(mockSystemCoin));

    assertEq(address(coinJoin.safeEngine()), _safeEngine);
  }

  function test_Set_SystemCoin(address _systemCoin) public happyPath {
    vm.assume(_systemCoin != address(0));
    coinJoin = new CoinJoinForTest(address(mockSafeEngine), _systemCoin);

    assertEq(address(coinJoin.systemCoin()), _systemCoin);
  }

  function test_Set_Decimals() public happyPath {
    assertEq(coinJoin.decimals(), 18);
  }

  function test_Revert_NullSafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    coinJoin = new CoinJoinForTest(address(0), address(mockSystemCoin));
  }

  function test_Revert_NullSystemCoin() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    coinJoin = new CoinJoinForTest(address(mockSafeEngine), address(0));
  }
}

contract Unit_CoinJoin_Join is Base {
  event Join(address _sender, address _account, uint256 _wad);

  modifier happyPath(uint256 _wad) {
    vm.startPrank(user);

    _assumeHappyPath(_wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal pure {
    vm.assume(notOverflowMul(RAY, _wad));
  }

  function _mockSystemCoinTransferFrom(address _from, address _to, uint256 _amount) internal {
    vm.mockCall(
      address(mockSystemCoin),
      abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _amount),
      abi.encode(true)
    );
  }

  function test_Revert_Overflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowMul(RAY, _wad));

    vm.expectRevert();

    coinJoin.join(_account, _wad);
  }

  function test_Call_SafeEngine_TransferInternalCoins(address _account, uint256 _wad) public happyPath(_wad) {
    _mockSystemCoinTransferFrom(user, address(coinJoin), _wad);
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (address(coinJoin), _account, RAY * _wad)),
      1
    );

    coinJoin.join(_account, _wad);
  }

  function test_Call_SystemCoin_Burn(address _account, uint256 _wad) public happyPath(_wad) {
    _mockSystemCoinTransferFrom(user, address(coinJoin), _wad);
    vm.expectCall(address(mockSystemCoin), abi.encodeWithSignature('burn(uint256)', _wad));
    coinJoin.join(_account, _wad);
  }

  function test_Emit_Join(address _account, uint256 _wad) public happyPath(_wad) {
    _mockSystemCoinTransferFrom(user, address(coinJoin), _wad);

    vm.expectEmit();
    emit Join(user, _account, _wad);

    coinJoin.join(_account, _wad);
  }
}

contract Unit_CoinJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  modifier happyPath(uint256 _wad) {
    vm.startPrank(user);

    _assumeHappyPath(_wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal pure {
    vm.assume(notOverflowMul(RAY, _wad));
  }

  function test_Revert_ContractIsDisabled(address _account, uint256 _wad) public {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    coinJoin.exit(_account, _wad);
  }

  function test_Revert_Overflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowMul(RAY, _wad));

    vm.expectRevert();

    coinJoin.exit(_account, _wad);
  }

  function test_Call_SafeEngine_TransferInternalCoins(address _account, uint256 _wad) public happyPath(_wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (user, address(coinJoin), RAY * _wad)),
      1
    );

    coinJoin.exit(_account, _wad);
  }

  function test_Call_SystemCoin_Mint(address _account, uint256 _wad) public happyPath(_wad) {
    vm.expectCall(address(mockSystemCoin), abi.encodeCall(mockSystemCoin.mint, (_account, _wad)), 1);

    coinJoin.exit(_account, _wad);
  }

  function test_Emit_Exit(address _account, uint256 _wad) public happyPath(_wad) {
    vm.expectEmit();
    emit Exit(user, _account, _wad);

    coinJoin.exit(_account, _wad);
  }
}
