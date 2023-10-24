// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {IAccountingEngine, AccountingEngine} from '@contracts/AccountingEngine.sol';
import {IDebtAuctionHouse, DebtAuctionHouse as DAH} from '@contracts/DebtAuctionHouse.sol';
import {ISurplusAuctionHouse, SurplusAuctionHouse as SAH_ONE} from '@contracts/SurplusAuctionHouse.sol';
import {
  IPostSettlementSurplusAuctionHouse,
  PostSettlementSurplusAuctionHouse as SAH_TWO
} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';
import {SettlementSurplusAuctioneer} from '@contracts/settlement/SettlementSurplusAuctioneer.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract SingleAccountingEngineTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  AccountingEngine accountingEngine;
  DAH debtAuctionHouse;
  SAH_ONE surplusAuctionHouseOne;
  SAH_TWO surplusAuctionHouseTwo;
  SettlementSurplusAuctioneer postSettlementSurplusDrain;
  ERC20ForTest protocolToken;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);

    protocolToken = new ERC20ForTest();

    IDebtAuctionHouse.DebtAuctionHouseParams memory _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18,
      amountSoldIncrease: 1.5e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    debtAuctionHouse = new DAH(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);
    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _sahParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.05e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days,
      bidReceiver: address(0x123),
      recyclingPercentage: 0
    });

    surplusAuctionHouseOne = new SAH_ONE(address(safeEngine), address(protocolToken), _sahParams);

    IAccountingEngine.AccountingEngineParams memory _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0,
      surplusDelay: 0,
      popDebtDelay: 0,
      disableCooldown: 0,
      surplusAmount: rad(100 ether),
      surplusBuffer: 0,
      debtAuctionMintedTokens: 200 ether,
      debtAuctionBidSize: rad(100 ether)
    });

    accountingEngine = new AccountingEngine(
          address(safeEngine), address(surplusAuctionHouseOne), address(debtAuctionHouse), _accountingEngineParams
        );
    surplusAuctionHouseOne.addAuthorization(address(accountingEngine));

    debtAuctionHouse.addAuthorization(address(accountingEngine));

    safeEngine.approveSAFEModification(address(debtAuctionHouse));
  }

  function _try_popDebtFromQueue(uint256 era) internal returns (bool ok) {
    string memory sig = 'popDebtFromQueue(uint256)';
    (ok,) = address(accountingEngine).call(abi.encodeWithSignature(sig, era));
  }

  function _try_decreaseSoldAmount(uint256 id, uint256 amountToBuy) internal returns (bool ok) {
    string memory sig = 'decreaseSoldAmount(uint256,uint256)';
    (ok,) = address(debtAuctionHouse).call(abi.encodeWithSignature(sig, id, amountToBuy));
  }

  function try_call(address addr, bytes calldata data) external returns (bool) {
    bytes memory _data = data;
    assembly {
      let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
      let free := mload(0x40)
      mstore(free, ok)
      mstore(0x40, add(free, 32))
      revert(free, 32)
    }
  }

  function can_auctionSurplus() public returns (bool) {
    string memory sig = 'auctionSurplus()';
    bytes memory data = abi.encodeWithSignature(sig);

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', accountingEngine, data);
    (bool ok, bytes memory success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
    if (ok) return true;
  }

  function can_TransferSurplus() public returns (bool) {
    string memory sig = 'transferExtraSurplus()';
    bytes memory data = abi.encodeWithSignature(sig);

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', accountingEngine, data);
    (bool ok, bytes memory success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
    if (ok) return true;
  }

  function can_auction_debt() public returns (bool) {
    string memory sig = 'auctionDebt()';
    bytes memory data = abi.encodeWithSignature(sig);

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', accountingEngine, data);
    (bool ok, bytes memory success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
    if (ok) return true;
  }

  uint256 constant ONE = 10 ** 27;

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * ONE;
  }

  function _popDebtFromQueue(uint256 wad) internal {
    accountingEngine.pushDebtToQueue(rad(wad));
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('', abi.encode(_safeEngineCollateralParams));
    safeEngine.createUnbackedDebt(address(accountingEngine), address(0), rad(wad));
    accountingEngine.popDebtFromQueue(block.timestamp);
  }

  function test_change_auction_houses() public {
    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _sahParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.05e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days,
      bidReceiver: address(0x123),
      recyclingPercentage: 0
    });

    SAH_ONE newSAH_ONE = new SAH_ONE(address(safeEngine), address(protocolToken), _sahParams);

    DAH newDAH = new DAH(address(safeEngine), address(protocolToken), 
    IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18,
      amountSoldIncrease: 1.5e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    }));

    newSAH_ONE.addAuthorization(address(accountingEngine));
    newDAH.addAuthorization(address(accountingEngine));

    assertTrue(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouseOne)));
    assertTrue(!safeEngine.canModifySAFE(address(accountingEngine), address(newSAH_ONE)));

    accountingEngine.modifyParameters('surplusAuctionHouse', abi.encode(newSAH_ONE));
    accountingEngine.modifyParameters('debtAuctionHouse', abi.encode(newDAH));

    assertEq(address(accountingEngine.surplusAuctionHouse()), address(newSAH_ONE));
    assertEq(address(accountingEngine.debtAuctionHouse()), address(newDAH));

    assertTrue(!safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouseOne)));
    assertTrue(safeEngine.canModifySAFE(address(accountingEngine), address(newSAH_ONE)));
  }

  function test_popDebtFromQueue_delay() public {
    AccountingEngine.AccountingEngineParams memory _params = accountingEngine.params();
    assertEq(_params.popDebtDelay, 0);
    accountingEngine.modifyParameters('popDebtDelay', abi.encode(uint256(100 seconds)));
    _params = accountingEngine.params();
    assertEq(_params.popDebtDelay, 100 seconds);

    uint256 tic = block.timestamp;
    accountingEngine.pushDebtToQueue(100 ether);
    assertTrue(!_try_popDebtFromQueue(tic));
    hevm.warp(block.timestamp + tic + 100 seconds);
    assertTrue(_try_popDebtFromQueue(tic));
  }

  function test_no_debt_auction_no_bid_size() public {
    accountingEngine.modifyParameters('debtAuctionBidSize', abi.encode(0));
    assertTrue(!can_auction_debt());
  }

  function test_no_reauction_debt() public {
    _popDebtFromQueue(100 ether);
    assertTrue(can_auction_debt());
    accountingEngine.auctionDebt();
    assertTrue(!can_auction_debt());
  }

  function test_debt_auction_pending_surplus() public {
    _popDebtFromQueue(200 ether);

    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(can_auction_debt());

    accountingEngine.settleDebt(rad(100 ether));
    assertTrue(can_auction_debt());
  }

  function test_debt_auction_less_unauction_debt_than_bid_size() public {
    accountingEngine.modifyParameters('debtAuctionBidSize', abi.encode(rad(150 ether)));

    _popDebtFromQueue(200 ether);
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));

    assertTrue(!can_auction_debt());
  }

  function testFail_pop_debt_after_being_popped() public {
    _popDebtFromQueue(100 ether);
    accountingEngine.popDebtFromQueue(block.timestamp);
  }

  function test_surplus_auction_when_transfer_permitted() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(uint256(1)));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(!can_auctionSurplus());
  }

  function test_auction_surplus_when_amount_null() public {
    accountingEngine.modifyParameters('surplusAmount', abi.encode(uint256(0)));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(!can_auctionSurplus());
  }

  function test_surplus_auction() public {
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(can_auctionSurplus());
  }

  function test_transfer_surplus_when_not_permitted() public {
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(uint256(100 ether)));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(!can_TransferSurplus());
  }

  function test_transfer_surplus_when_receiver_not_defined() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(uint256(1)));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(uint256(100 ether)));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(!can_TransferSurplus());
  }

  function test_transfer_surplus_when_amount_not_defined() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(!can_auctionSurplus());
  }

  function test_surplus_transfer() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(100 ether));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    assertTrue(!can_auctionSurplus());
    assertTrue(can_TransferSurplus());
  }

  function test_surplus_transfer_twice_in_a_row() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(100 ether));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(200 ether));
    accountingEngine.transferExtraSurplus();
    assertEq(safeEngine.coinBalance(address(1)), 100 ether);
    assertTrue(can_TransferSurplus());
    accountingEngine.transferExtraSurplus();
    assertEq(safeEngine.coinBalance(address(1)), 200 ether);
  }

  function test_surplus_transfer_after_waiting() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(100 ether));
    accountingEngine.modifyParameters('surplusDelay', abi.encode(1));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(200 ether));
    assertTrue(!can_TransferSurplus());
    hevm.warp(block.timestamp + 1);
    accountingEngine.transferExtraSurplus();
    assertEq(safeEngine.coinBalance(address(1)), 100 ether);
    assertTrue(!can_TransferSurplus());
  }

  function test_settlement_auction_surplus() public {
    // Post settlement auction house setup
    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _pssahParams = IPostSettlementSurplusAuctionHouse
      .PostSettlementSAHParams({bidIncrease: 1.05e18, bidDuration: 3 hours, totalAuctionLength: 2 days});
    surplusAuctionHouseTwo = new SAH_TWO(address(safeEngine), address(protocolToken), _pssahParams);
    // Auctioneer setup
    postSettlementSurplusDrain =
      new SettlementSurplusAuctioneer(address(accountingEngine), address(surplusAuctionHouseTwo));
    surplusAuctionHouseTwo.addAuthorization(address(postSettlementSurplusDrain));

    safeEngine.createUnbackedDebt(address(0), address(postSettlementSurplusDrain), rad(100 ether));
    accountingEngine.disableContract();
    uint256 id = postSettlementSurplusDrain.auctionSurplus();
    assertEq(id, 1);
  }

  function test_settlement_delay_transfer_surplus() public {
    // Post settlement auction house setup
    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _pssahParams = IPostSettlementSurplusAuctionHouse
      .PostSettlementSAHParams({bidIncrease: 1.05e18, bidDuration: 3 hours, totalAuctionLength: 2 days});
    surplusAuctionHouseTwo = new SAH_TWO(address(safeEngine), address(protocolToken), _pssahParams);
    // Auctioneer setup
    postSettlementSurplusDrain =
      new SettlementSurplusAuctioneer(address(accountingEngine), address(surplusAuctionHouseTwo));
    surplusAuctionHouseTwo.addAuthorization(address(postSettlementSurplusDrain));

    accountingEngine.modifyParameters('postSettlementSurplusDrain', abi.encode(postSettlementSurplusDrain));
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));

    accountingEngine.modifyParameters('disableCooldown', abi.encode(1));
    accountingEngine.disableContract();

    assertEq(safeEngine.coinBalance(address(accountingEngine)), rad(100 ether));
    assertEq(safeEngine.coinBalance(address(postSettlementSurplusDrain)), 0);
    hevm.warp(block.timestamp + 1);

    accountingEngine.transferPostSettlementSurplus();
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
    assertEq(safeEngine.coinBalance(address(postSettlementSurplusDrain)), rad(100 ether));

    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));
    accountingEngine.transferPostSettlementSurplus();
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
    assertEq(safeEngine.coinBalance(address(postSettlementSurplusDrain)), rad(200 ether));
  }

  function test_no_surplus_auction_pending_debt() public {
    accountingEngine.modifyParameters('surplusAmount', abi.encode(uint256(0 ether)));
    _popDebtFromQueue(100 ether);

    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(50 ether));
    assertTrue(!can_auctionSurplus());
  }

  function test_no_transfer_surplus_pending_debt() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(0 ether));

    _popDebtFromQueue(100 ether);
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(50 ether));
    assertTrue(!can_TransferSurplus());
  }

  function test_no_surplus_auction_nonzero_bad_debt() public {
    accountingEngine.modifyParameters('surplusAmount', abi.encode(uint256(0 ether)));
    _popDebtFromQueue(100 ether);
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(50 ether));
    assertTrue(!can_auctionSurplus());
  }

  function test_no_transfer_surplus_nonzero_bad_debt() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(0));

    _popDebtFromQueue(100 ether);
    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(50 ether));
    assertTrue(!can_TransferSurplus());
  }

  function test_no_surplus_auction_pending_debt_auction() public {
    _popDebtFromQueue(100 ether);
    accountingEngine.debtAuctionHouse();

    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));

    assertTrue(!can_auctionSurplus());
  }

  function test_no_transfer_surplus_pending_debt_auction() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));

    _popDebtFromQueue(100 ether);
    accountingEngine.debtAuctionHouse();

    safeEngine.createUnbackedDebt(address(0), address(accountingEngine), rad(100 ether));

    assertTrue(!can_TransferSurplus());
  }

  function test_no_surplus_auction_pending_settleDebt() public {
    _popDebtFromQueue(100 ether);
    uint256 id = accountingEngine.auctionDebt();

    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    debtAuctionHouse.decreaseSoldAmount(id, 0 ether);

    assertTrue(!can_auctionSurplus());
  }

  function test_no_transfer_surplus_pending_settleDebt() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));

    _popDebtFromQueue(100 ether);
    uint256 id = accountingEngine.auctionDebt();

    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    debtAuctionHouse.decreaseSoldAmount(id, 0 ether);

    assertTrue(!can_TransferSurplus());
  }

  function test_no_surplus_after_good_debt_auction() public {
    _popDebtFromQueue(100 ether);
    uint256 id = accountingEngine.auctionDebt();
    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));

    debtAuctionHouse.decreaseSoldAmount(id, 0 ether); // debt auction succeeds..

    assertTrue(!can_auctionSurplus());
  }

  function test_no_transfer_surplus_after_good_debt_auction() public {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(1));

    _popDebtFromQueue(100 ether);
    uint256 id = accountingEngine.auctionDebt();
    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));

    debtAuctionHouse.decreaseSoldAmount(id, 0 ether); // debt auction succeeds..

    assertTrue(!can_TransferSurplus());
  }

  function test_multiple_increaseBidSize() public {
    _popDebtFromQueue(100 ether);
    uint256 id = accountingEngine.auctionDebt();

    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    assertTrue(_try_decreaseSoldAmount(id, 2 ether));

    safeEngine.createUnbackedDebt(address(0), address(this), rad(100 ether));
    assertTrue(_try_decreaseSoldAmount(id, 1 ether));
  }
}
