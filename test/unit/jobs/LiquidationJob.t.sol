// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {LiquidationJobForTest, ILiquidationJob} from '@test/mocks/LiquidationJobForTest.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
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

  ILiquidationEngine mockLiquidationEngine = ILiquidationEngine(mockContract('LiquidationEngine'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  LiquidationJobForTest liquidationJob;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    liquidationJob =
      new LiquidationJobForTest(address(mockLiquidationEngine), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(liquidationJob), 'LiquidationJob');

    liquidationJob.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockLiquidateSAFE(bytes32 _cType, address _safe, uint256 _id) internal {
    vm.mockCall(
      address(mockLiquidationEngine),
      abi.encodeCall(mockLiquidationEngine.liquidateSAFE, (_cType, _safe)),
      abi.encode(_id)
    );
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(liquidationJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  function _mockShouldWork(bool _shouldWork) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    liquidationJob.setShouldWork(_shouldWork);
  }
}

contract Unit_LiquidationJob_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new LiquidationJobForTest(address(mockLiquidationEngine), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(liquidationJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(liquidationJob.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Set_LiquidationEngine(address _liquidationEngine) public happyPath mockAsContract(_liquidationEngine) {
    liquidationJob = new LiquidationJobForTest(_liquidationEngine, address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(liquidationJob.liquidationEngine()), _liquidationEngine);
  }

  function test_Set_ShouldWork() public happyPath {
    assertEq(liquidationJob.shouldWork(), true);
  }

  function test_Revert_Null_LiquidationEngine() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new LiquidationJobForTest(address(0), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new LiquidationJobForTest(address(mockLiquidationEngine), address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new LiquidationJobForTest(address(mockLiquidationEngine), address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_LiquidationJob_WorkLiquidation is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  function _mockValues(bool _shouldWork, bytes32 _cType, address _safe) internal {
    _mockShouldWork(_shouldWork);
    _mockLiquidateSAFE(_cType, _safe, 1);
  }

  function test_Revert_NotWorkable() public {
    bytes32 _cType = 'randomCType';
    address _safe = newAddress();
    _mockValues(false, _cType, _safe);

    vm.expectRevert(IJob.NotWorkable.selector);

    liquidationJob.workLiquidation(_cType, _safe);
  }

  function test_Call_LiquidationEngine_LiquidateSAFE(bytes32 _cType, address _safe) public {
    _mockValues(true, _cType, _safe);

    liquidationJob.workLiquidation(_cType, _safe);
  }

  function test_Emit_Rewarded(bytes32 _cType, address _safe) public {
    _mockValues(true, _cType, _safe);

    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    vm.prank(user);
    liquidationJob.workLiquidation(_cType, _safe);
  }
}

contract Unit_LiquidationJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_LiquidationEngine(address _liquidationEngine) public happyPath mockAsContract(_liquidationEngine) {
    liquidationJob.modifyParameters('liquidationEngine', abi.encode(_liquidationEngine));

    assertEq(address(liquidationJob.liquidationEngine()), _liquidationEngine);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    liquidationJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(liquidationJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShouldWorkPopDebtFromQueue(bool _shouldWork) public happyPath {
    liquidationJob.modifyParameters('shouldWork', abi.encode(_shouldWork));

    assertEq(liquidationJob.shouldWork(), _shouldWork);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    liquidationJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(liquidationJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_LiquidationEngine() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    liquidationJob.modifyParameters('liquidationEngine', abi.encode(address(0)));
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    liquidationJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    liquidationJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    liquidationJob.modifyParameters('unrecognizedParam', _data);
  }
}
