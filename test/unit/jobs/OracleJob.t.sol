// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {OracleJobForTest, IOracleJob} from '@test/mocks/OracleJobForTest.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IOracleRelayer mockOracleRelayer = IOracleRelayer(mockContract('OracleRelayer'));
  IDelayedOracle mockDelayedOracle = IDelayedOracle(mockContract('DelayedOracle'));
  IPIDRateSetter mockPIDRateSetter = IPIDRateSetter(mockContract('PIDRateSetter'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  OracleJobForTest oracleJob;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    oracleJob =
    new OracleJobForTest(address(mockOracleRelayer), address(mockPIDRateSetter), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(oracleJob), 'OracleJob');

    oracleJob.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockOracleRelayerCollateralParams(
    bytes32 _cType,
    address _oracle,
    uint256 _safetyCRatio,
    uint256 _liquidationCRatio
  ) internal {
    vm.mockCall(
      address(mockOracleRelayer),
      abi.encodeCall(mockOracleRelayer.cParams, (_cType)),
      abi.encode(_oracle, _safetyCRatio, _liquidationCRatio)
    );
  }

  function _mockUpdateResult(bool _success) internal {
    vm.mockCall(address(mockDelayedOracle), abi.encodeCall(mockDelayedOracle.updateResult, ()), abi.encode(_success));
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(oracleJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  function _mockShouldWorkUpdateCollateralPrice(bool _shouldWorkUpdateCollateralPrice) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    oracleJob.setShouldWorkUpdateCollateralPrice(_shouldWorkUpdateCollateralPrice);
  }

  function _mockShouldWorkUpdateRate(bool _shouldWorkUpdateRate) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    oracleJob.setShouldWorkUpdateRate(_shouldWorkUpdateRate);
  }
}

contract Unit_OracleJob_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new OracleJobForTest(address(mockOracleRelayer), address(mockPIDRateSetter), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(oracleJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(oracleJob.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Set_OracleRelayer(address _oracleRelayer) public happyPath mockAsContract(_oracleRelayer) {
    oracleJob =
      new OracleJobForTest(_oracleRelayer, address(mockPIDRateSetter), address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(oracleJob.oracleRelayer()), _oracleRelayer);
  }

  function test_Set_PIDRateSetter(address _pidRateSetter) public happyPath mockAsContract(_pidRateSetter) {
    oracleJob =
      new OracleJobForTest(address(mockOracleRelayer), _pidRateSetter, address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(oracleJob.pidRateSetter()), _pidRateSetter);
  }

  function test_Set_ShouldWorkUpdateCollateralPrice() public happyPath {
    assertEq(oracleJob.shouldWorkUpdateCollateralPrice(), true);
  }

  function test_Set_ShouldWorkUpdateRate() public happyPath {
    assertEq(oracleJob.shouldWorkUpdateRate(), true);
  }

  function test_Revert_Null_OracleRelayer() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new OracleJobForTest(address(0), address(mockPIDRateSetter), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_PIDRateSetter() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new OracleJobForTest(address(mockOracleRelayer), address(0), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new OracleJobForTest(address(mockOracleRelayer), address(mockPIDRateSetter), address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new OracleJobForTest(address(mockOracleRelayer), address(mockPIDRateSetter), address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_OracleJob_WorkUpdateCollateralPrice is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath(bytes32 _cType) {
    vm.startPrank(user);

    _mockValues(_cType, true, true);
    _;
  }

  function _mockValues(bytes32 _cType, bool _shouldWorkUpdateCollateralPrice, bool _updateResult) internal {
    _mockShouldWorkUpdateCollateralPrice(_shouldWorkUpdateCollateralPrice);
    _mockOracleRelayerCollateralParams(_cType, address(mockDelayedOracle), 0, 0);
    _mockUpdateResult(_updateResult);
  }

  function test_Revert_NotWorkable(bytes32 _cType) public {
    _mockValues(_cType, false, false);

    vm.expectRevert(IJob.NotWorkable.selector);

    oracleJob.workUpdateCollateralPrice(_cType);
  }

  function test_Revert_InvalidPrice(bytes32 _cType) public {
    _mockValues(_cType, true, false);

    vm.expectRevert(IOracleJob.OracleJob_InvalidPrice.selector);

    oracleJob.workUpdateCollateralPrice(_cType);
  }

  function test_Call_OracleRelayer_UpdateCollateralPrice(bytes32 _cType) public happyPath(_cType) {
    vm.expectCall(address(mockOracleRelayer), abi.encodeCall(mockOracleRelayer.updateCollateralPrice, (_cType)), 1);

    oracleJob.workUpdateCollateralPrice(_cType);
  }

  function test_Emit_Rewarded(bytes32 _cType) public happyPath(_cType) {
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    oracleJob.workUpdateCollateralPrice(_cType);
  }
}

contract Unit_OracleJob_WorkUpdateRate is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath() {
    vm.startPrank(user);

    _mockValues(true);
    _;
  }

  function _mockValues(bool _shouldWorkUpdateRate) internal {
    _mockShouldWorkUpdateRate(_shouldWorkUpdateRate);
  }

  function test_Revert_NotWorkable() public {
    _mockValues(false);

    vm.expectRevert(IJob.NotWorkable.selector);

    oracleJob.workUpdateRate();
  }

  function test_Call_PIDRateSetter_UpdateRate() public happyPath {
    vm.expectCall(address(mockPIDRateSetter), abi.encodeCall(mockPIDRateSetter.updateRate, ()), 1);

    oracleJob.workUpdateRate();
  }

  function test_Emit_Rewarded() public happyPath {
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    oracleJob.workUpdateRate();
  }
}

contract Unit_OracleJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_OracleRelayer(address _oracleRelayer) public happyPath mockAsContract(_oracleRelayer) {
    oracleJob.modifyParameters('oracleRelayer', abi.encode(_oracleRelayer));

    assertEq(address(oracleJob.oracleRelayer()), _oracleRelayer);
  }

  function test_Set_PIDRateSetter(address _pidRateSetter) public happyPath mockAsContract(_pidRateSetter) {
    oracleJob.modifyParameters('pidRateSetter', abi.encode(_pidRateSetter));

    assertEq(address(oracleJob.pidRateSetter()), _pidRateSetter);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    oracleJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(oracleJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShouldWorkUpdateCollateralPrice(bool _shouldWorkUpdateCollateralPrice) public happyPath {
    oracleJob.modifyParameters('shouldWorkUpdateCollateralPrice', abi.encode(_shouldWorkUpdateCollateralPrice));

    assertEq(oracleJob.shouldWorkUpdateCollateralPrice(), _shouldWorkUpdateCollateralPrice);
  }

  function test_Set_ShouldWorkUpdateRate(bool _shouldWorkUpdateRate) public happyPath {
    oracleJob.modifyParameters('shouldWorkUpdateRate', abi.encode(_shouldWorkUpdateRate));

    assertEq(oracleJob.shouldWorkUpdateRate(), _shouldWorkUpdateRate);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    oracleJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(oracleJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_OracleRelayer() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    oracleJob.modifyParameters('oracleRelayer', abi.encode(address(0)));
  }

  function test_Revert_Null_PIDRateSetter() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    oracleJob.modifyParameters('pidRateSetter', abi.encode(address(0)));
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    oracleJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    oracleJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    oracleJob.modifyParameters('unrecognizedParam', _data);
  }
}
