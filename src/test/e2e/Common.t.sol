// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PRBTest} from 'prb-test/PRBTest.sol';
import '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {Contracts, CollateralJoin, ERC20ForTest} from '@script/Contracts.s.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {Math} from '@libraries/Math.sol';

uint256 constant YEAR = 365 days;
uint256 constant RAY = 1e27;
uint256 constant RAD_DELTA = 0.0001e45;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 HAI

contract DeployForTest is Deploy {
  function _setupEnvironment() internal virtual override {
    oracle[HAI] = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD
    oracle[ETH_A] = new OracleForTest(TEST_ETH_PRICE); // 1 ETH = 2000 USD
    oracle[TKN] = new OracleForTest(TEST_TKN_PRICE); // 1 TKN = 1 USD

    collateralTypes.push(ETH_A);
    collateralParams[ETH_A] = CollateralParams({
      name: ETH_A,
      oracle: oracle[ETH_A],
      liquidationPenalty: ETH_A_LIQUIDATION_PENALTY,
      liquidationQuantity: ETH_A_LIQUIDATION_QUANTITY,
      debtCeiling: ETH_A_DEBT_CEILING,
      safetyCRatio: ETH_A_SAFETY_C_RATIO,
      liquidationRatio: ETH_A_LIQUIDATION_RATIO,
      stabilityFee: ETH_A_STABILITY_FEE,
      percentageOfStabilityFeeToTreasury: PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
    });

    collateralTypes.push(TKN);
    collateralParams[TKN] = CollateralParams({
      name: TKN,
      oracle: oracle[TKN],
      liquidationPenalty: TKN_LIQUIDATION_PENALTY,
      liquidationQuantity: TKN_LIQUIDATION_QUANTITY,
      debtCeiling: TKN_DEBT_CEILING,
      safetyCRatio: TKN_SAFETY_C_RATIO,
      liquidationRatio: TKN_LIQUIDATION_RATIO,
      stabilityFee: TKN_STABILITY_FEE,
      percentageOfStabilityFeeToTreasury: PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
    });
  }
}

abstract contract Common is PRBTest, Contracts {
  DeployForTest deployment;
  address deployer;

  address alice = address(0x420);
  address bob = address(0x421);
  address carol = address(0x422);
  address dave = address(0x423);

  uint256 auctionId;

  function setUp() public {
    deployment = new DeployForTest();
    deployment.run();
    deployer = deployment.deployer();

    vm.label(deployer, 'Deployer');
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    vm.label(carol, 'Carol');
    vm.label(dave, 'Dave');

    safeEngine = deployment.safeEngine();
    accountingEngine = deployment.accountingEngine();
    taxCollector = deployment.taxCollector();
    stabilityFeeTreasury = deployment.stabilityFeeTreasury();
    debtAuctionHouse = deployment.debtAuctionHouse();
    surplusAuctionHouse = deployment.surplusAuctionHouse();
    liquidationEngine = deployment.liquidationEngine();
    oracleRelayer = deployment.oracleRelayer();
    coinJoin = deployment.coinJoin();
    coin = deployment.coin();
    protocolToken = deployment.protocolToken();

    ethJoin = deployment.ethJoin();
    oracle[ETH_A] = deployment.oracle(ETH_A);
    collateralAuctionHouse[ETH_A] = deployment.collateralAuctionHouse(ETH_A);

    globalSettlement = deployment.globalSettlement();
  }

  function _joinETH(address _user, uint256 _amount) internal {
    vm.startPrank(_user);
    vm.deal(_user, _amount);
    ethJoin.join{value: _amount}(_user); // 100 ETH
    vm.stopPrank();
  }

  function _joinTKN(address _user, CollateralJoin _collateralJoin, uint256 _amount) internal {
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
      _cType: CollateralJoin(_collateralJoin).collateralType(),
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
