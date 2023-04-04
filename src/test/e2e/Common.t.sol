// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PRBTest} from 'prb-test/PRBTest.sol';
import '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {Contracts, OracleForTest} from '@script/Contracts.s.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {Math} from '../../contracts/utils/Math.sol';

uint256 constant YEAR = 365 days;
uint256 constant RAY = 1e27;
uint256 constant RAD_DELTA = 0.0001e45;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 HAI

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
    debtAuctionHouse = deployment.debtAuctionHouse();
    surplusAuctionHouse = deployment.surplusAuctionHouse();
    liquidationEngine = deployment.liquidationEngine();
    oracleRelayer = deployment.oracleRelayer();
    coinJoin = deployment.coinJoin();
    coin = deployment.coin();
    protocolToken = deployment.protocolToken();

    ethJoin = deployment.ethJoin();
    ethOracle = deployment.ethOracle();
    collateralAuctionHouse = deployment.ethCollateralAuctionHouse();

    globalSettlement = deployment.globalSettlement();
  }

  function _joinETH(address _user, uint256 _amount) internal {
    vm.startPrank(_user);
    vm.deal(_user, _amount);
    ethJoin.join{value: _amount}(_user); // 100 ETH
    vm.stopPrank();
  }

  function _openSafe(address _user, int256 _deltaCollat, int256 _deltaDebt) internal {
    vm.startPrank(_user);

    safeEngine.approveSAFEModification(address(ethJoin));

    safeEngine.modifySAFECollateralization({
      collateralType: ETH_A,
      safe: _user,
      collateralSource: _user,
      debtDestination: _user,
      deltaCollateral: _deltaCollat,
      deltaDebt: _deltaDebt
    });

    vm.stopPrank();
  }

  function _setCollateralPrice(bytes32 _collateral, uint256 _price) internal {
    (IOracle _oracle,,) = oracleRelayer.collateralTypes(_collateral);
    OracleForTest(address(_oracle)).setPriceAndValidity(_price, true);
    oracleRelayer.updateCollateralPrice(_collateral);
  }

  function _collectFees(uint256 _timeToWarp) internal {
    vm.warp(block.timestamp + _timeToWarp);
    taxCollector.taxSingle(ETH_A);
  }
}
