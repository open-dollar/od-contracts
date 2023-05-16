// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PRBTest} from 'prb-test/PRBTest.sol';
import '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {Contracts, OracleForTest, CollateralJoin, ERC20ForTest} from '@script/Contracts.s.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {Math} from '@libraries/Math.sol';

uint256 constant YEAR = 365 days;
uint256 constant RAY = 1e27;
uint256 constant RAD_DELTA = 0.0001e45;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 HAI

interface ICollateralJoinLike {
  function collateralType() external view returns (bytes32);
}

abstract contract Common is PRBTest, Contracts {
  Deploy deployment;
  address deployer;

  address alice = address(0x420);
  address bob = address(0x421);
  address carol = address(0x422);
  address dave = address(0x423);

  uint256 auctionId;

  function setUp() public {
    deployment = new Deploy();
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
      _cType: ICollateralJoinLike(_collateralJoin).collateralType(),
      _safe: _user,
      _collateralSource: _user,
      _debtDestination: _user,
      _deltaCollateral: _deltaCollat,
      _deltaDebt: _deltaDebt
    });

    vm.stopPrank();
  }

  function _setCollateralPrice(bytes32 _collateral, uint256 _price) internal {
    IOracle _oracle = oracleRelayer.cParams(_collateral).oracle;
    OracleForTest(address(_oracle)).setPriceAndValidity(_price, true);
    oracleRelayer.updateCollateralPrice(_collateral);
  }

  function _collectFees(uint256 _timeToWarp) internal {
    vm.warp(block.timestamp + _timeToWarp);
    taxCollector.taxSingle(ETH_A);
  }
}
