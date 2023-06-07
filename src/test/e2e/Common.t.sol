// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {HAI, ETH_A, HAI_INITIAL_PRICE} from '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {TestParams, TKN, TEST_ETH_PRICE, TEST_TKN_PRICE} from '@test/e2e/TestParams.s.sol';
import {Contracts, ICollateralJoin, ERC20ForTest} from '@script/Contracts.s.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {Math, RAY} from '@libraries/Math.sol';

uint256 constant RAD_DELTA = 0.0001e45;
uint256 constant COLLATERAL_PRICE = 100e18;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 HAI

contract DeployForTest is Deploy, TestParams {
  function _setupEnvironment() internal virtual override {
    oracle[HAI] = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD
    oracle[ETH_A] = new OracleForTest(TEST_ETH_PRICE); // 1 ETH = 2000 USD
    oracle[TKN] = new OracleForTest(TEST_TKN_PRICE); // 1 TKN = 1 USD

    collateral[ETH_A] = new ERC20ForTest();
    collateral[TKN] = new ERC20ForTest();

    oracle['TKN-A'] = new OracleForTest(COLLATERAL_PRICE);
    oracle['TKN-B'] = new OracleForTest(COLLATERAL_PRICE);
    oracle['TKN-C'] = new OracleForTest(COLLATERAL_PRICE);

    collateral['TKN-A'] = new ERC20ForTest();
    collateral['TKN-B'] = new ERC20ForTest();
    collateral['TKN-C'] = new ERC20ForTest();

    collateralTypes.push(ETH_A);
    collateralTypes.push(TKN);
    collateralTypes.push('TKN-A');
    collateralTypes.push('TKN-B');
    collateralTypes.push('TKN-C');

    _getEnvironmentParams();
  }
}

abstract contract Common is HaiTest, DeployForTest {
  address alice = address(0x420);
  address bob = address(0x421);
  address carol = address(0x422);
  address dave = address(0x423);

  uint256 auctionId;

  function setUp() public {
    run();

    vm.label(deployer, 'Deployer');
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    vm.label(carol, 'Carol');
    vm.label(dave, 'Dave');
  }

  function _joinETH(address _user, uint256 _amount) internal {
    vm.startPrank(_user);
    vm.deal(_user, _amount);
    ethJoin.join{value: _amount}(_user); // 100 ETH
    vm.stopPrank();
  }

  function _joinTKN(address _user, ICollateralJoin _collateralJoin, uint256 _amount) internal {
    vm.startPrank(_user);
    ERC20ForTest _collateral = ERC20ForTest(address(_collateralJoin.collateral()));
    _collateral.mint(_user, _amount);
    _collateral.approve(address(_collateralJoin), _amount);
    _collateralJoin.join(_user, _amount);
    vm.stopPrank();
  }

  function _openSafe(address _user, address _collateralJoin, int256 _deltaCollat, int256 _deltaDebt) internal {
    vm.startPrank(_user);

    safeEngine.approveSAFEModification(_collateralJoin);

    safeEngine.modifySAFECollateralization({
      _cType: ICollateralJoin(_collateralJoin).collateralType(),
      _safe: _user,
      _collateralSource: _user,
      _debtDestination: _user,
      _deltaCollateral: _deltaCollat,
      _deltaDebt: _deltaDebt
    });

    vm.stopPrank();
  }

  function _setCollateralPrice(bytes32 _collateral, uint256 _price) internal {
    IBaseOracle _oracle = oracleRelayer.cParams(_collateral).oracle;
    vm.mockCall(
      address(_oracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector), abi.encode(_price, true)
    );
    vm.mockCall(address(_oracle), abi.encodeWithSelector(IBaseOracle.read.selector), abi.encode(_price));
    oracleRelayer.updateCollateralPrice(_collateral);
  }

  function _collectFees(uint256 _timeToWarp) internal {
    vm.warp(block.timestamp + _timeToWarp);
    taxCollector.taxSingle(ETH_A);
  }
}
