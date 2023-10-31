// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';

import {TaxCollectorForTest as TaxCollector, ITaxCollector} from '@test/mocks/TaxCollectorForTest.sol';
import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';

import {RAY} from '@libraries/Math.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract SingleTaxCollectorTest is DSTest {
  Hevm hevm;
  TaxCollector taxCollector;
  SAFEEngine safeEngine;

  function ray(uint256 _wad) internal pure returns (uint256) {
    return _wad * 10 ** 9;
  }

  function rad(uint256 _wad) internal pure returns (uint256) {
    return _wad * 10 ** 27;
  }

  function wad(uint256 _rad) internal pure returns (uint256) {
    return _rad / 10 ** 27;
  }

  function wad(int256 _rad) internal pure returns (uint256) {
    return uint256(_rad / 10 ** 27);
  }

  function _updateTime(bytes32 _collateralType) internal view returns (uint256) {
    return taxCollector.cData(_collateralType).updateTime;
  }

  address ali = address(bytes20('ali'));
  address bob = address(bytes20('bob'));
  address char = address(bytes20('char'));

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);

    ITaxCollector.TaxCollectorParams memory _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(0x744),
      globalStabilityFee: RAY,
      maxStabilityFeeRange: RAY - 1,
      maxSecondaryReceivers: 0
    });
    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);
    safeEngine.addAuthorization(address(taxCollector));
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('i', abi.encode(_safeEngineCollateralParams));

    draw('i', 100 ether);
  }

  function draw(bytes32 collateralType, uint256 _coin) internal {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams = safeEngine.cParams(collateralType);
    uint256 _globalDebtCeiling = safeEngine.params().globalDebtCeiling;
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(_globalDebtCeiling + rad(_coin)));
    safeEngine.modifyParameters(collateralType, 'debtCeiling', abi.encode(_safeEngineCParams.debtCeiling + rad(_coin)));
    uint256 _collateralPrice = 10 ** 27 * 10_000 ether;
    safeEngine.updateCollateralPrice(collateralType, _collateralPrice, _collateralPrice);
    address self = address(this);
    safeEngine.modifyCollateralBalance(collateralType, self, 10 ** 27 * 1 ether);
    safeEngine.modifySAFECollateralization(collateralType, self, self, self, int256(1 ether), int256(_coin));
  }

  function test_collect_tax_setup() public {
    hevm.warp(0);
    assertEq(uint256(block.timestamp), 0);
    hevm.warp(1);
    assertEq(uint256(block.timestamp), 1);
    hevm.warp(2);
    assertEq(uint256(block.timestamp), 2);
    assertEq(safeEngine.cData('i').debtAmount, 100 ether);
  }

  function test_collect_tax_updates__updateTime() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    assertEq(_updateTime('i'), block.timestamp);

    taxCollector.taxSingle('i');
    assertEq(_updateTime('i'), block.timestamp);
    hevm.warp(block.timestamp + 1);
    assertEq(_updateTime('i'), block.timestamp - 1);
    taxCollector.taxSingle('i');
    assertEq(_updateTime('i'), block.timestamp);
    hevm.warp(block.timestamp + 1 days);
    taxCollector.taxSingle('i');
    assertEq(_updateTime('i'), block.timestamp);
  }

  function test_collect_tax_modifyParameters() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.taxSingle('i');
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_000_000_564_701_133_626_865_910_626)); // 5% / day
  }

  function test_collect_tax_0d() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: 1_000_000_564_701_133_626_865_910_626}); // 5% / day
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    assertEq(safeEngine.coinBalance(ali), rad(0 ether));
    taxCollector.taxSingle('i');
    assertEq(safeEngine.coinBalance(ali), rad(0 ether));
  }

  function test_collect_tax_1d() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: 1_000_000_564_701_133_626_865_910_626}); // 5% / day
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.taxSingle('i');

    hevm.warp(block.timestamp + 1 days);
    assertEq(wad(safeEngine.coinBalance(ali)), 0 ether);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 5 ether);
  }

  function test_collect_tax_2d() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: 1_000_000_564_701_133_626_865_910_626}); // 5% / day
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.taxSingle('i');

    hevm.warp(block.timestamp + 2 days);
    assertEq(wad(safeEngine.coinBalance(ali)), 0 ether);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 10.25 ether);
  }

  function test_collect_tax_3d() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: 1_000_000_564_701_133_626_865_910_626}); // 5% / day
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.taxSingle('i');

    hevm.warp(block.timestamp + 3 days);
    assertEq(wad(safeEngine.coinBalance(ali)), 0 ether);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 15.7625 ether);
  }

  function test_collect_tax_negative_3d() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: 999_999_706_969_857_929_985_428_567}); // -2.5% / day
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.taxSingle('i');

    hevm.warp(block.timestamp + 3 days);
    assertEq(wad(safeEngine.coinBalance(address(this))), 100 ether);
    safeEngine.transferInternalCoins(address(this), ali, rad(100 ether));
    assertEq(wad(safeEngine.coinBalance(ali)), 100 ether);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 92.6859375 ether);
  }

  function test_collect_tax_multi() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: 1_000_000_564_701_133_626_865_910_626}); // 5% / day
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.taxSingle('i');

    hevm.warp(block.timestamp + 1 days);
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_000_001_103_127_689_513_476_993_127)); // 10% / day
    taxCollector.taxSingle('i');

    assertEq(wad(safeEngine.coinBalance(ali)), 5 ether);
    hevm.warp(block.timestamp + 1 days);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 15.5 ether);
    assertEq(wad(safeEngine.globalDebt()), 115.5 ether);
    assertEq(safeEngine.cData('i').accumulatedRate / 10 ** 9, 1.155 ether);
  }

  function test_collect_tax_global_stability_fee() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);

    taxCollector.modifyParameters('globalStabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_000_000_000_000_000_000_000_000_000)); // 0% / second
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 10.25 ether);
  }

  function test_collect_tax_all_positive() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);

    taxCollector.modifyParameters('globalStabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_030_000_000_000_000_000_000_000_000)); // 3% / second
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    taxCollector.taxMany(0, taxCollector.collateralListLength() - 1);

    assertEq(wad(safeEngine.coinBalance(ali)), 18.4 ether);

    assertEq(taxCollector.cData('i').updateTime, block.timestamp);
    assertEq(taxCollector.cData('j').updateTime, block.timestamp);

    assertTrue(taxCollector.collectedManyTax(0, 1));
  }

  function test_collect_tax_all_some_negative() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);

    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(900_000_000_000_000_000_000_000_000));
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 10);
    taxCollector.taxSingle('i');
    assertEq(wad(safeEngine.coinBalance(ali)), 62_889_462_677_744_140_625);

    taxCollector.taxSingle('j');
    assertEq(wad(safeEngine.coinBalance(ali)), 0);

    assertEq(taxCollector.cData('i').updateTime, block.timestamp);
    assertEq(taxCollector.cData('i').updateTime, block.timestamp);

    assertTrue(taxCollector.collectedManyTax(0, 1));
  }

  function testFail_cut_at_hundred() public {
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(10));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 1 ether, canTakeBackTax: false}))
    );
  }

  function testFail_add_over_maxSecondaryReceivers() public {
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(1));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(ali), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
  }

  function testFail_modify_cut_total_over_hundred() public {
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(1));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 1.1 ether, canTakeBackTax: false}))
    );
  }

  function testFail_tax_receiver_primaryTaxReceiver() public {
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(1));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: ali, taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
  }

  function testFail_tax_receiver_null() public {
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(1));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(0), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
  }

  function test_add_tax_secondaryTaxReceivers() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));

    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    assertEq(taxCollector.cData('i').secondaryReceiverAllotedTax, 0.01 ether);
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 1);
    ITaxCollector.TaxReceiver memory _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertTrue(!_taxReceiver.canTakeBackTax);
    assertEq(_taxReceiver.taxPercentage, 0.01 ether);
  }

  function test_modify_tax_receiver_cut() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));

    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(1));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(
        ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.999 ether, canTakeBackTax: false})
      )
    );

    uint256 _cut = taxCollector.cData('i').secondaryReceiverAllotedTax;
    assertEq(_cut, 0.999 ether);
    ITaxCollector.TaxReceiver memory _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertEq(_taxReceiver.taxPercentage, 0.999 ether);
  }

  function test_remove_some_tax_secondaryTaxReceivers() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));

    // Add
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: ali, taxPercentage: 0.98 ether, canTakeBackTax: false}))
    );

    assertEq(taxCollector.cData('i').secondaryReceiverAllotedTax, 0.99 ether);
    assertEq(taxCollector.secondaryReceiverRevenueSources(ali), 1);
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 1);
    ITaxCollector.TaxReceiver memory _taxReceiver = taxCollector.secondaryTaxReceivers('i', ali);
    assertTrue(!_taxReceiver.canTakeBackTax);
    assertEq(_taxReceiver.taxPercentage, 0.98 ether);
    // Remove
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0, canTakeBackTax: false}))
    );
    assertEq(taxCollector.cData('i').secondaryReceiverAllotedTax, 0.98 ether);
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 0);
    _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertTrue(!_taxReceiver.canTakeBackTax);
    assertEq(_taxReceiver.taxPercentage, 0);
    assertEq(taxCollector.secondaryReceiverRevenueSources(ali), 1);
  }

  function test_remove_all_secondaryTaxReceivers() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));

    // Add
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: ali, taxPercentage: 0.98 ether, canTakeBackTax: false}))
    );
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 1);
    assertEq(taxCollector.secondaryReceiverRevenueSources(ali), 1);
    // Remove
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: ali, taxPercentage: 0, canTakeBackTax: false}))
    );
    uint256 Cut = taxCollector.cData('i').secondaryReceiverAllotedTax;
    assertEq(Cut, 0);
    assertEq(taxCollector.secondaryReceiverRevenueSources(ali), 0);
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 0);
    ITaxCollector.TaxReceiver memory _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertTrue(!_taxReceiver.canTakeBackTax);
    assertEq(_taxReceiver.taxPercentage, 0);
  }

  function test_add_remove_add_secondaryTaxReceivers() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));

    // Add
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    assertTrue(taxCollector.isSecondaryReceiver(address(this)));
    // Remove
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0, canTakeBackTax: false}))
    );
    assertTrue(!taxCollector.isSecondaryReceiver(address(this)));
    // Add again
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    assertEq(taxCollector.cData('i').secondaryReceiverAllotedTax, 0.01 ether);
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 1);
    assertEq(taxCollector.secondaryReceiversAmount(), 1);
    assertTrue(taxCollector.isSecondaryReceiver(address(this)));
    ITaxCollector.TaxReceiver memory _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertTrue(!_taxReceiver.canTakeBackTax);
    assertEq(_taxReceiver.taxPercentage, 0.01 ether);

    // Remove again
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0, canTakeBackTax: false}))
    );
    assertEq(taxCollector.cData('i').secondaryReceiverAllotedTax, 0);
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 0);
    assertTrue(!taxCollector.isSecondaryReceiver(address(this)));
    _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertTrue(!_taxReceiver.canTakeBackTax);
    assertEq(_taxReceiver.taxPercentage, 0);
  }

  function test_multi_collateral_types_receivers() public {
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(1));

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);

    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'j',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: false}))
    );

    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 2);

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0, canTakeBackTax: false}))
    );
    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 1);

    taxCollector.modifyParameters(
      'j',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0, canTakeBackTax: false}))
    );

    assertEq(taxCollector.secondaryReceiverRevenueSources(address(this)), 0);
  }

  function test_toggle_receiver_take() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));

    // Add
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: address(this), taxPercentage: 0.01 ether, canTakeBackTax: true}))
    );

    // Toggle
    ITaxCollector.TaxReceiver memory _taxReceiver = taxCollector.secondaryTaxReceivers('i', address(this));
    assertTrue(_taxReceiver.canTakeBackTax);
  }

  function test_add_secondaryTaxReceivers_single_collateral_type_collect_tax_positive() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));
    taxCollector.taxSingle('i');

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.4 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.45 ether, canTakeBackTax: false}))
    );

    hevm.warp(block.timestamp + 10);
    (, int256 currentRates) = taxCollector.taxSingleOutcome('i');
    taxCollector.taxSingle('i');

    assertEq(wad(safeEngine.coinBalance(ali)), 9_433_419_401_661_621_093);
    assertEq(wad(safeEngine.coinBalance(bob)), 25_155_785_071_097_656_250);
    assertEq(wad(safeEngine.coinBalance(char)), 28_300_258_204_984_863_281);

    assertEq(wad(safeEngine.coinBalance(ali)) * ray(100 ether) / uint256(currentRates), 1_499_999_999_999_999_999_880);
    assertEq(wad(safeEngine.coinBalance(bob)) * ray(100 ether) / uint256(currentRates), 4_000_000_000_000_000_000_000);
    assertEq(wad(safeEngine.coinBalance(char)) * ray(100 ether) / uint256(currentRates), 4_499_999_999_999_999_999_960);
  }

  function testFail_tax_when_safe_engine_is_disabled() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));
    taxCollector.taxSingle('i'); // next stability fee is updated at this call

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.4 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.45 ether, canTakeBackTax: false}))
    );

    safeEngine.disableContract();
    hevm.warp(block.timestamp + 10);
    taxCollector.taxSingle('i');
  }

  function test_add_secondaryTaxReceivers_multi_collateral_types_collect_tax_positive() public {
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));

    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));

    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.4 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.45 ether, canTakeBackTax: false}))
    );

    hevm.warp(block.timestamp + 10);
    taxCollector.taxMany(0, taxCollector.collateralListLength() - 1);

    assertEq(wad(safeEngine.coinBalance(ali)), 72_322_882_079_405_761_718);
    assertEq(wad(safeEngine.coinBalance(bob)), 25_155_785_071_097_656_250);
    assertEq(wad(safeEngine.coinBalance(char)), 28_300_258_204_984_863_281);

    taxCollector.modifyParameters(
      'j',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.25 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'j',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.33 ether, canTakeBackTax: false}))
    );

    hevm.warp(block.timestamp + 10);
    taxCollector.taxMany(0, taxCollector.collateralListLength() - 1);

    assertEq(wad(safeEngine.coinBalance(ali)), 130_713_857_546_323_549_197);
    assertEq(wad(safeEngine.coinBalance(bob)), 91_741_985_164_951_273_550);
    assertEq(wad(safeEngine.coinBalance(char)), 108_203_698_317_609_204_041);

    assertEq(taxCollector.cData('i').secondaryReceiverAllotedTax, 0.85 ether);
    assertEq(taxCollector.secondaryReceiverRevenueSources(bob), 2);
    assertEq(taxCollector.secondaryReceiverRevenueSources(char), 2);
    assertEq(taxCollector.secondaryReceiversAmount(), 2);
    assertTrue(taxCollector.isSecondaryReceiver(bob));
    assertTrue(taxCollector.isSecondaryReceiver(char));

    ITaxCollector.TaxReceiver memory _bob = taxCollector.secondaryTaxReceivers('i', bob);
    assertTrue(!_bob.canTakeBackTax);
    assertEq(_bob.taxPercentage, 0.4 ether);

    ITaxCollector.TaxReceiver memory _char = taxCollector.secondaryTaxReceivers('i', char);
    assertTrue(!_char.canTakeBackTax);
    assertEq(_char.taxPercentage, 0.45 ether);

    _bob = taxCollector.secondaryTaxReceivers('j', bob);
    assertTrue(!_bob.canTakeBackTax);
    assertEq(_bob.taxPercentage, 0.25 ether);

    _char = taxCollector.secondaryTaxReceivers('j', char);
    assertTrue(!_char.canTakeBackTax);
    assertEq(_char.taxPercentage, 0.33 ether);
  }

  function test_add_secondaryTaxReceivers_single_collateral_type_toggle_collect_tax_negative() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));

    taxCollector.taxSingle('i');

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.05 ether, canTakeBackTax: true}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.1 ether, canTakeBackTax: true}))
    );

    // note: modifies the stability fee to take effect at the next taxation
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(900_000_000_000_000_000_000_000_000));
    hevm.warp(block.timestamp + 5);
    taxCollector.taxSingle('i');

    assertEq(wad(safeEngine.coinBalance(ali)), 23_483_932_812_500_000_000);
    assertEq(wad(safeEngine.coinBalance(bob)), 1_381_407_812_500_000_000);
    assertEq(wad(safeEngine.coinBalance(char)), 2_762_815_625_000_000_000);

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.1 ether, canTakeBackTax: true}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.2 ether, canTakeBackTax: true}))
    );

    hevm.warp(block.timestamp + 5);
    taxCollector.taxSingle('i');

    assertEq(wad(safeEngine.coinBalance(ali)), 0);
    assertEq(wad(safeEngine.coinBalance(bob)), 0);
    assertEq(wad(safeEngine.coinBalance(char)), 0);
  }

  function test_add_secondaryTaxReceivers_multi_collateral_types_toggle_collect_tax_negative() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));

    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.05 ether, canTakeBackTax: true}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.1 ether, canTakeBackTax: true}))
    );

    hevm.warp(block.timestamp + 5);
    taxCollector.taxMany(0, taxCollector.collateralListLength() - 1);

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(900_000_000_000_000_000_000_000_000));
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(900_000_000_000_000_000_000_000_000));
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.1 ether, canTakeBackTax: true}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.25 ether, canTakeBackTax: true}))
    );

    taxCollector.modifyParameters(
      'j',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.1 ether, canTakeBackTax: true}))
    );
    taxCollector.modifyParameters(
      'j',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.2 ether, canTakeBackTax: true}))
    );

    hevm.warp(block.timestamp + 5);
    taxCollector.taxMany(0, taxCollector.collateralListLength() - 1);

    assertEq(wad(safeEngine.coinBalance(ali)), 0);
    assertEq(wad(safeEngine.coinBalance(bob)), 0);
    assertEq(wad(safeEngine.coinBalance(char)), 0);
  }

  function test_add_secondaryTaxReceivers_no_toggle_collect_tax_negative() public {
    // Setup
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000));
    taxCollector.taxSingle('i');

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(2));
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.05 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.1 ether, canTakeBackTax: false}))
    );

    // note: modifies the stability fee to take effect at the next taxation
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(900_000_000_000_000_000_000_000_000));
    hevm.warp(block.timestamp + 5);
    taxCollector.taxSingle('i');

    assertEq(wad(safeEngine.coinBalance(ali)), 23_483_932_812_500_000_000);
    assertEq(wad(safeEngine.coinBalance(bob)), 1_381_407_812_500_000_000);
    assertEq(wad(safeEngine.coinBalance(char)), 2_762_815_625_000_000_000);

    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: bob, taxPercentage: 0.1 ether, canTakeBackTax: false}))
    );
    taxCollector.modifyParameters(
      'i',
      'secondaryTaxReceiver',
      abi.encode(ITaxCollector.TaxReceiver({receiver: char, taxPercentage: 0.2 ether, canTakeBackTax: false}))
    );

    hevm.warp(block.timestamp + 5);
    taxCollector.taxSingle('i');

    assertEq(wad(safeEngine.coinBalance(ali)), 0);
    assertEq(wad(safeEngine.coinBalance(bob)), 1_381_407_812_500_000_000);
    assertEq(wad(safeEngine.coinBalance(char)), 2_762_815_625_000_000_000);
  }

  function test_collectedManyTax() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);

    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_000_000_000_000_000_000_000_000_000)); // 0% / second
    taxCollector.modifyParameters('globalStabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second

    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    assertTrue(!taxCollector.collectedManyTax(0, 1));

    taxCollector.taxSingle('i');
    assertTrue(taxCollector.collectedManyTax(0, 0));
    assertTrue(!taxCollector.collectedManyTax(0, 1));
  }

  function test_modify_stabilityFee() public {
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1));

    assertEq(taxCollector.cParams('i').stabilityFee, 1);
  }

  function test_taxManyOutcome_all_untaxed_positive_rates() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('i', 100 ether);
    draw('j', 100 ether);

    taxCollector.modifyParameters('globalStabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_030_000_000_000_000_000_000_000_000)); // 3% / second
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    (bool _ok, int256 _rad) = taxCollector.taxManyOutcome(0, 1);
    assertTrue(_ok);
    assertEq(uint256(_rad), 28.65 * 10 ** 45);
  }

  function test_taxManyOutcome_some_untaxed_positive_rates() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('i', 100 ether);
    draw('j', 100 ether);

    taxCollector.modifyParameters('globalStabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_030_000_000_000_000_000_000_000_000)); // 3% / second
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    taxCollector.taxSingle('i');
    (bool _ok, int256 _rad) = taxCollector.taxManyOutcome(0, 1);
    assertTrue(_ok);
    assertEq(uint256(_rad), 8.15 * 10 ** 45);
  }

  function test_taxManyOutcome_all_untaxed_negative_rates() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('i', 100 ether);
    draw('j', 100 ether);

    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(950_000_000_000_000_000_000_000_000)); // -5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(930_000_000_000_000_000_000_000_000)); // -3% / second
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    (bool _ok, int256 _rad) = taxCollector.taxManyOutcome(0, 1);
    assertTrue(!_ok);
    assertEq(_rad, -17 * 10 ** 45);
  }

  function test_taxManyOutcome_all_untaxed_mixed_rates() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    draw('j', 100 ether);

    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('i', abi.encode(_taxCollectorCollateralParams));
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    taxCollector.modifyParameters('i', 'stabilityFee', abi.encode(950_000_000_000_000_000_000_000_000)); // -5% / second
    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(1_050_000_000_000_000_000_000_000_000)); // 5% / second
    taxCollector.taxSingle('i');
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 1);
    (bool _ok, int256 _rad) = taxCollector.taxManyOutcome(0, 1);
    assertTrue(_ok);
    assertEq(_rad, 0);
  }

  function test_negative_tax_accumulated_goes_negative() public {
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('j', abi.encode(_safeEngineCollateralParams));
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCollateralParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY});
    taxCollector.initializeCollateralType('j', abi.encode(_taxCollectorCollateralParams));
    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(ali));

    draw('j', 100 ether);
    safeEngine.transferInternalCoins(address(this), ali, safeEngine.coinBalance(address(this)));
    assertEq(wad(safeEngine.coinBalance(ali)), 200 ether);

    taxCollector.modifyParameters('j', 'stabilityFee', abi.encode(999_999_706_969_857_929_985_428_567)); // -2.5% / day
    taxCollector.taxSingle('j');

    hevm.warp(block.timestamp + 3 days);
    taxCollector.taxSingle('j');
    assertEq(wad(safeEngine.coinBalance(ali)), 192.6859375 ether);

    uint256 __accumulatedRate = safeEngine.cData('j').accumulatedRate;
    assertEq(__accumulatedRate, 926_859_375_000_000_000_000_022_885);
  }
}
