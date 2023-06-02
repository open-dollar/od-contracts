// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Math, RAY, WAD} from '@libraries/Math.sol';

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {InternalCallsWatcher, InternalCallsExtension} from '@test/utils/InternalCallsWatcher.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {
  IIncreasingDiscountCollateralAuctionHouse,
  IncreasingDiscountCollateralAuctionHouse
} from '@contracts/CollateralAuctionHouse.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {
  IncreasingDiscountCollateralAuctionHouseForTest,
  MockCollateralAuctionHouse
} from '@contracts/for-test/CollateralAuctionHouseForTest.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

import '@script/Params.s.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address mockSafeEngine = label('mockSafeEngine');
  address mockLiquidationEngine = label('mockLiquidationEngine');
  bytes32 mockCollateralType = 'mockCollateralType';
  address watcher;
  MockCollateralAuctionHouse mockCollateralAuctionHouse = new MockCollateralAuctionHouse();
  OracleForTest mockCollateralFSM = new OracleForTest(1 ether);
  OracleForTest mockMarketOracle = new OracleForTest(1 ether);
  OracleForTest mockSystemCoinOracle = new OracleForTest(1 ether);

  IIncreasingDiscountCollateralAuctionHouse auctionHouse;
  IOracleRelayer mockOracleRelayer = IOracleRelayer(mockContract('mockOracleRelayer'));

  function setUp() public virtual {
    vm.prank(deployer);
    auctionHouse =
    new IncreasingDiscountCollateralAuctionHouseForTest(mockSafeEngine, mockLiquidationEngine, mockCollateralType, mockCollateralAuctionHouse);
    watcher = address(IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).watcher());
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setCollateralFSM(
      IDelayedOracle(address(mockCollateralFSM))
    );
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setSystemCoinOracle(mockSystemCoinOracle);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setOracleRelayer(mockOracleRelayer);
  }

  function _setCallSuper(bool _callSuper) internal {
    vm.prank(deployer);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setCallSuper(_callSuper);
  }

  // --- SystemCoin Params ---

  function _mockMinSystemCoinMarketDeviation(uint256 _minSystemCoinDeviation) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.params.selector).depth(0)
      .checked_write(_minSystemCoinDeviation);
  }

  function _mockLowerSystemCoinMarketDeviation(uint256 _lowerSystemCoinDeviation) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.params.selector).depth(1)
      .checked_write(_lowerSystemCoinDeviation);
  }

  function _mockUpperSystemCoinMarketDeviation(uint256 _upperSystemCoinDeviation) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.params.selector).depth(2)
      .checked_write(_upperSystemCoinDeviation);
  }

  // --- Collateral Params ---

  function _mockMinimumBid(uint256 _minumumBid) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.cParams.selector).depth(0)
      .checked_write(_minumumBid);
  }

  function _mockMinDiscount(uint256 _minDiscount) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.cParams.selector).depth(1)
      .checked_write(_minDiscount);
  }

  function _mockMaxDiscount(uint256 _maxDiscount) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.cParams.selector).depth(2)
      .checked_write(_maxDiscount);
  }

  function _mockPerSecondDiscountUpdateRate(uint256 _perSecondDiscountUpdateRate) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.cParams.selector).depth(3)
      .checked_write(_perSecondDiscountUpdateRate);
  }

  function _mockLowerCollateralMarketDeviation(uint256 _lowerCollateralDeviation) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.cParams.selector).depth(4)
      .checked_write(_lowerCollateralDeviation);
  }

  function _mockUpperCollateralMarketDeviation(uint256 _upperCollateralDeviation) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.cParams.selector).depth(5)
      .checked_write(_upperCollateralDeviation);
  }

  // --- Data ---

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(auctionHouse)).sig(IIncreasingDiscountCollateralAuctionHouse.auctionsStarted.selector)
      .checked_write(_auctionsStarted);
  }

  function _mockLastReadRedemptionPrice(uint256 _lastReadRedemptionPrice) internal {
    stdstore.target(address(auctionHouse)).sig(
      IIncreasingDiscountCollateralAuctionHouse.lastReadRedemptionPrice.selector
    ).checked_write(_lastReadRedemptionPrice);
  }

  // --- Mocked calls ---

  function _mockLiquidationEngineRemoveCoinsFromAuction(uint256 _rad) internal {
    vm.mockCall(
      mockLiquidationEngine,
      abi.encodeWithSelector(ILiquidationEngine.removeCoinsFromAuction.selector, _rad),
      abi.encode(0)
    );
  }

  function _mockLiquidationEngineRemoveCoinsFromAuction() internal {
    vm.mockCall(
      mockLiquidationEngine, abi.encodeWithSelector(ILiquidationEngine.removeCoinsFromAuction.selector), abi.encode(0)
    );
  }

  function _mockSafeEngineTransferCollateral(address _destination, uint256 _wad) internal {
    vm.mockCall(
      mockSafeEngine,
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector, mockCollateralType, address(auctionHouse), _destination, _wad
      ),
      abi.encode(0)
    );
  }

  function _mockSafeEngineTransferInternalCoins() internal {
    vm.mockCall(mockSafeEngine, abi.encodeWithSelector(ISAFEEngine.transferInternalCoins.selector), abi.encode(0));
  }

  function _mockSafeEngineTransferCollateralStartAuction(uint256 _amountToSell) internal {
    vm.mockCall(
      mockSafeEngine,
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector,
        mockCollateralType,
        address(deployer),
        address(auctionHouse),
        _amountToSell
      ),
      abi.encode(0)
    );
  }

  // Internal Mocks, mocking for all the inputs because we just care about the output in these cases
  function _mockGetDiscountedCollateralPrice(uint256 _discountedCollateralPrice) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getDiscountedCollateralPrice.selector),
      abi.encode(_discountedCollateralPrice)
    );
  }

  function _mockCollateralFSMPriceSource(address _priceSource) internal {
    vm.mockCall(
      address(mockCollateralFSM), abi.encodeWithSelector(OracleForTest.priceSource.selector), abi.encode(_priceSource)
    );
  }

  function _mockGetNextCurrentDiscount(uint256 _nextCurrentDiscount) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getNextCurrentDiscount.selector),
      abi.encode(_nextCurrentDiscount)
    );
  }

  function _mockGetSystemCoinMarketPrice(uint256 _priceFeed) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getSystemCoinMarketPrice.selector),
      abi.encode(_priceFeed)
    );
  }

  function _mockGetFinalSystemCoinPrice(uint256 _finalSystemCoinPrice) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getFinalSystemCoinPrice.selector),
      abi.encode(_finalSystemCoinPrice)
    );
  }

  function _mockGetFinalBaseCollateralPrice(uint256 _adjustedMarketPrice) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getFinalBaseCollateralPrice.selector),
      abi.encode(_adjustedMarketPrice)
    );
  }

  function _mockGetSystemCoinFloorDeviatedPrice(uint256 _floorDeviatedPrice) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getSystemCoinFloorDeviatedPrice.selector),
      abi.encode(_floorDeviatedPrice)
    );
  }

  function _mockGetSystemCoinCeilingDeviatedPrice(uint256 _ceilingDeviatedPrice) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getSystemCoinCeilingDeviatedPrice.selector),
      abi.encode(_ceilingDeviatedPrice)
    );
  }

  function _mockGetAdjustedBid(bool _valid, uint256 _adjustedBid) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getAdjustedBid.selector),
      abi.encode(_valid, _adjustedBid)
    );
  }

  function _mockGetCollateralFSMAndFinalSystemCoinPrices(
    uint256 _cFsmPriceFeedValue,
    uint256 _sCoinAdjustedPrice
  ) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getCollateralFSMAndFinalSystemCoinPrices.selector),
      abi.encode(_cFsmPriceFeedValue, _sCoinAdjustedPrice)
    );
  }

  function _mockGetBoughtCollateral(uint256 _boughtCollateral) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getBoughtCollateral.selector),
      abi.encode(_boughtCollateral)
    );
  }

  function _mockGetCollateralMarketPrice(uint256 _collateralMarketPrice) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_getCollateralMarketPrice.selector),
      abi.encode(_collateralMarketPrice)
    );
  }

  function _mockUpdateCurrentDiscount(uint256 _discount) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeWithSelector(MockCollateralAuctionHouse.mock_updateCurrentDiscount.selector),
      abi.encode(_discount)
    );
  }

  function _mockOracleRelayerRedemptionPrice(uint256 _redemptionPrice) internal {
    vm.mockCall(
      address(mockOracleRelayer),
      abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector),
      abi.encode(_redemptionPrice)
    );
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }
}

contract Unit_CollateralAuctionHouse_Constructor is Base {
  function test_Set_SafeEngine() public {
    assertEq(address(auctionHouse.safeEngine()), mockSafeEngine);
  }

  function test_Set_LiquidationEngine() public {
    assertEq(address(auctionHouse.liquidationEngine()), mockLiquidationEngine);
  }

  function test_Set_CollateralType() public {
    assertEq(auctionHouse.collateralType(), mockCollateralType);
  }

  function test_Set_AuthorizedAccounts() public {
    assertEq(auctionHouse.authorizedAccounts(deployer), 1);
  }
}

contract Unit_CollateralAuctionHouse_AmountToRaise is Base {
  function test_AmountToRaise(uint8 _auctionsAmount, uint256 _amountToRaise) public {
    vm.assume(_auctionsAmount > 0 && _auctionsAmount <= 100);

    for (uint8 i = 1; i < _auctionsAmount; i++) {
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
        IIncreasingDiscountCollateralAuctionHouse.Auction({
          amountToSell: 0,
          amountToRaise: 0,
          currentDiscount: 0,
          maxDiscount: 0,
          perSecondDiscountUpdateRate: 0,
          latestDiscountUpdateTime: 0,
          forgoneCollateralReceiver: address(0),
          auctionIncomeRecipient: address(0)
        })
      );
    }
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: 0,
        amountToRaise: _amountToRaise,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );

    assertEq(auctionHouse.amountToRaise(_auctionsAmount), _amountToRaise);
  }
}

contract Unit_CollateralAuctionHouse_ForgoneCollateralReceiver is Base {
  function test_ForgoneCollateralReceiver(uint8 _auctionsAmount, address _forgoneCollateralReceiver) public {
    vm.assume(_auctionsAmount > 0 && _auctionsAmount <= 100);

    for (uint8 i = 1; i < _auctionsAmount; i++) {
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
        IIncreasingDiscountCollateralAuctionHouse.Auction({
          amountToSell: 0,
          amountToRaise: 0,
          currentDiscount: 0,
          maxDiscount: 0,
          perSecondDiscountUpdateRate: 0,
          latestDiscountUpdateTime: 0,
          forgoneCollateralReceiver: address(0),
          auctionIncomeRecipient: address(0)
        })
      );
    }
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: 0,
        amountToRaise: 0,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: _forgoneCollateralReceiver,
        auctionIncomeRecipient: address(0)
      })
    );

    assertEq(auctionHouse.forgoneCollateralReceiver(_auctionsAmount), _forgoneCollateralReceiver);
  }
}

contract Unit_CollateralAuctionHouse_RemainingAmountToSell is Base {
  function test_RemainingAmountToSell(uint8 _auctionsAmount, uint256 _remainingAmountToSell) public {
    vm.assume(_auctionsAmount > 0 && _auctionsAmount <= 100);

    for (uint8 i = 1; i < _auctionsAmount; i++) {
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
        IIncreasingDiscountCollateralAuctionHouse.Auction({
          amountToSell: 0,
          amountToRaise: 0,
          currentDiscount: 0,
          maxDiscount: 0,
          perSecondDiscountUpdateRate: 0,
          latestDiscountUpdateTime: 0,
          forgoneCollateralReceiver: address(0),
          auctionIncomeRecipient: address(0)
        })
      );
    }
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _remainingAmountToSell,
        amountToRaise: 0,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );

    assertEq(auctionHouse.remainingAmountToSell(_auctionsAmount), _remainingAmountToSell);
  }
}

contract Unit_CollateralAuctionHouse_TerminateAuctionPrematurely is Base {
  function _mockValues(uint256 _amountToSell, uint256 _amountToRaise) internal {
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _amountToSell,
        amountToRaise: _amountToRaise,
        currentDiscount: 1,
        maxDiscount: 1,
        perSecondDiscountUpdateRate: 1,
        latestDiscountUpdateTime: 1,
        forgoneCollateralReceiver: newAddress(),
        auctionIncomeRecipient: newAddress()
      })
    );

    _mockLiquidationEngineRemoveCoinsFromAuction(_amountToRaise);
    _mockSafeEngineTransferCollateral(deployer, _amountToSell);
  }

  function test_Call_LiquidationEngine_RemoveCoinsFromAuction(
    uint256 _amountToSell,
    uint256 _amountToRaise
  ) public authorized {
    vm.assume(_amountToSell > 0 && _amountToRaise > 0);
    _mockValues(_amountToSell, _amountToRaise);

    vm.expectCall(
      mockLiquidationEngine, abi.encodeWithSelector(ILiquidationEngine.removeCoinsFromAuction.selector, _amountToRaise)
    );
    auctionHouse.terminateAuctionPrematurely(1);
  }

  function test_Call_SafeEngine_TransferCollateral(uint256 _amountToSell, uint256 _amountToRaise) public authorized {
    vm.assume(_amountToSell > 0 && _amountToRaise > 0);
    _mockValues(_amountToSell, _amountToRaise);
    vm.expectCall(
      mockSafeEngine,
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector, mockCollateralType, address(auctionHouse), deployer, _amountToSell
      )
    );
    auctionHouse.terminateAuctionPrematurely(1);
  }

  event TerminateAuctionPrematurely(uint256 indexed _id, address _sender, uint256 _collateralAmount);

  function test_Emit_TerminateAuctionPrematurely(uint256 _amountToSell, uint256 _amountToRaise) public authorized {
    vm.assume(_amountToSell > 0 && _amountToRaise > 0);
    _mockValues(_amountToSell, _amountToRaise);
    vm.expectEmit(true, false, false, true);
    emit TerminateAuctionPrematurely(1, deployer, 0);
    auctionHouse.terminateAuctionPrematurely(1);
  }

  function test_Delete_Bid(uint256 _amountToSell, uint256 _amountToRaise) public authorized {
    vm.assume(_amountToSell > 0 && _amountToRaise > 0);
    _mockValues(_amountToSell, _amountToRaise);

    auctionHouse.terminateAuctionPrematurely(1);

    bytes memory _result = abi.encode(auctionHouse.auctions(1));
    IIncreasingDiscountCollateralAuctionHouse.Auction memory _emptyAuction;
    bytes memory _emptyAuctionBytes = abi.encode(_emptyAuction);

    assertEq(_result, _emptyAuctionBytes);
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    auctionHouse.terminateAuctionPrematurely(1);
  }

  function test_Revert_AmountToSell_IsZero(uint256 _amountToRaise) public authorized {
    _mockValues(0, _amountToRaise);
    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/inexistent-auction'));
    auctionHouse.terminateAuctionPrematurely(1);
  }

  function test_Revert_AmountToRaise_IsZero(uint256 _amountToSell) public authorized {
    _mockValues(_amountToSell, 0);
    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/inexistent-auction'));
    auctionHouse.terminateAuctionPrematurely(1);
  }
}

contract Unit_CollateralAuctionHouse_GetBoughtCollateral is Base {
  using Math for uint256;

  function setUp() public virtual override {
    super.setUp();
    _setCallSuper(false);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setCallSupper_getDiscountedCollateralPrice(
      false
    );
  }

  struct GetBoughtCollateralScenario {
    // method arguments
    uint256 collateralFsmPriceFeedValue;
    uint256 collateralMarketPriceFeedValue;
    uint256 systemCoinPriceFeedValue;
    uint256 adjustedBid;
    uint256 customDiscount;
    // internal method returns
    uint256 discountedCollateralPrice;
    // bid values
    uint256 amountToSell;
  }

  function _happyPath(GetBoughtCollateralScenario memory _scenario) internal pure {
    vm.assume(_scenario.discountedCollateralPrice > 0);
    vm.assume(notOverflowMul(_scenario.adjustedBid, WAD));
  }

  function _boughtCollateralGreaterThanAmountToSell(GetBoughtCollateralScenario memory _scenario)
    internal
    pure
    returns (bool)
  {
    return _scenario.adjustedBid.wdiv(_scenario.discountedCollateralPrice) > _scenario.amountToSell;
  }

  modifier amountToSellLessThanBoughtCollateral(GetBoughtCollateralScenario memory _scenario) {
    _happyPath(_scenario);
    vm.assume(_boughtCollateralGreaterThanAmountToSell(_scenario));
    _;
  }

  modifier amountToSellGreaterThanBoughtCollateral(GetBoughtCollateralScenario memory _scenario) {
    _happyPath(_scenario);
    vm.assume(!_boughtCollateralGreaterThanAmountToSell(_scenario));
    _;
  }

  function test_Call_Internal_GetDiscountedCollateralPrice(GetBoughtCollateralScenario memory _scenario) public {
    _happyPath(_scenario);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _scenario.amountToSell,
        amountToRaise: 0,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );
    _mockGetDiscountedCollateralPrice(_scenario.discountedCollateralPrice);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getDiscountedCollateralPrice(uint256,uint256,uint256,uint256)',
          _scenario.collateralFsmPriceFeedValue,
          _scenario.collateralMarketPriceFeedValue,
          _scenario.systemCoinPriceFeedValue,
          _scenario.customDiscount
        )
      )
    );

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_getBoughtCollateral(
      1,
      _scenario.collateralFsmPriceFeedValue,
      _scenario.collateralMarketPriceFeedValue,
      _scenario.systemCoinPriceFeedValue,
      _scenario.adjustedBid,
      _scenario.customDiscount
    );
  }

  function test_Return_BoughtCollateral(GetBoughtCollateralScenario memory _scenario)
    public
    amountToSellGreaterThanBoughtCollateral(_scenario)
  {
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _scenario.amountToSell,
        amountToRaise: 0,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );
    _mockGetDiscountedCollateralPrice(_scenario.discountedCollateralPrice);
    uint256 _boughtCollateral = _scenario.adjustedBid.wdiv(_scenario.discountedCollateralPrice);
    uint256 _result = IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_getBoughtCollateral(
      1,
      _scenario.collateralFsmPriceFeedValue,
      _scenario.collateralMarketPriceFeedValue,
      _scenario.systemCoinPriceFeedValue,
      _scenario.adjustedBid,
      _scenario.customDiscount
    );
    assertEq(_result, _boughtCollateral);
  }

  function test_Return_AmountToSell(GetBoughtCollateralScenario memory _scenario)
    public
    amountToSellLessThanBoughtCollateral(_scenario)
  {
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _scenario.amountToSell,
        amountToRaise: 0,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );
    _mockGetDiscountedCollateralPrice(_scenario.discountedCollateralPrice);
    uint256 _result = IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_getBoughtCollateral(
      1,
      _scenario.collateralFsmPriceFeedValue,
      _scenario.collateralMarketPriceFeedValue,
      _scenario.systemCoinPriceFeedValue,
      _scenario.adjustedBid,
      _scenario.customDiscount
    );
    assertEq(_result, _scenario.amountToSell);
  }
}

contract Unit_CollateralAuctionHouse_UpdateCurrentDisconunt is Base {
  function test_Call_Internal_GetNextCurrentDiscount(uint256 _id) public {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector, abi.encodeWithSignature('_getNextCurrentDiscount(uint256)', _id)
      ),
      1
    );

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_updateCurrentDiscount(_id);
  }

  function test_Set_Bid_LatestDiscountUpdateTime(uint256 _id) public {
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_updateCurrentDiscount(_id);
    assertEq(auctionHouse.auctions(_id).latestDiscountUpdateTime, block.timestamp);
  }

  function test_Set_NextCurrentDiscount(uint256 _id, uint256 _nextCurrentDiscount) public {
    _setCallSuper(false);
    _mockGetNextCurrentDiscount(_nextCurrentDiscount);

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_updateCurrentDiscount(_id);
    assertEq(auctionHouse.auctions(_id).currentDiscount, _nextCurrentDiscount);
  }

  function test_Return_NextCurrentDiscount(uint256 _id, uint256 _nextCurrentDiscount) public {
    _setCallSuper(false);
    _mockGetNextCurrentDiscount(_nextCurrentDiscount);

    assertEq(
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).call_updateCurrentDiscount(_id),
      _nextCurrentDiscount
    );
  }
}

contract Unit_CollateralAuctionHouse_GetCollateralMarketPrice is Base {
  function test_Call_CollateralFSM_PriceSource() public {
    vm.expectCall(address(mockCollateralFSM), abi.encodeWithSelector(IDelayedOracle.priceSource.selector));
    _mockCollateralFSMPriceSource(address(mockMarketOracle));

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice();
  }

  function test_Call_MarketOracle_GetResultWithValidity() public {
    vm.expectCall(address(mockMarketOracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector));
    _mockCollateralFSMPriceSource(address(mockMarketOracle));

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice();
  }

  function test_Return_Zero_MarketOracleIsZeroAddress() public {
    _mockCollateralFSMPriceSource(address(0));
    uint256 _collateralMarketPrice =
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice();
    assertEq(_collateralMarketPrice, 0);
  }

  function test_Return_Zero_PriceSource_ThrowsError() public {
    mockCollateralFSM.setThrowsError(true);

    uint256 _collateralMarketPrice =
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice();
    assertEq(_collateralMarketPrice, 0);
  }

  function test_Return_Zero_GetResultWithValidity_ThrowsError() public {
    _mockCollateralFSMPriceSource(address(mockMarketOracle));
    mockMarketOracle.setThrowsError(true);

    uint256 _collateralMarketPrice =
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice();
    assertEq(_collateralMarketPrice, 0);
  }

  function test_Return_Zero_GetResultWithValidity_NotValid() public {
    _mockCollateralFSMPriceSource(address(mockMarketOracle));
    mockMarketOracle.setPriceAndValidity(1 ether, false);

    uint256 _collateralMarketPrice =
      IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice();
    assertEq(_collateralMarketPrice, 0);
  }

  function test_Return_GetResultWithValidity(uint256 _price) public {
    _mockCollateralFSMPriceSource(address(mockMarketOracle));
    mockMarketOracle.setPriceAndValidity(_price, true);

    assertEq(IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).getCollateralMarketPrice(), _price);
  }
}

contract Unit_CollateralAuctionHouse_GetSystemCoinMarketPrice is Base {
  function test_Call_SystemCoinOracle_GetResultWithValidity() public {
    vm.expectCall(address(mockSystemCoinOracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector));

    auctionHouse.getSystemCoinMarketPrice();
  }

  function test_Return_Zero_SystemCoinOracleZeroAddress() public {
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setSystemCoinOracle(IBaseOracle(address(0)));
    assertEq(auctionHouse.getSystemCoinMarketPrice(), 0);
  }

  function test_Return_Zero_ResultNotValid() public {
    mockSystemCoinOracle.setPriceAndValidity(1 ether, false);
    assertEq(auctionHouse.getSystemCoinMarketPrice(), 0);
  }

  function test_Return_Zero_GetResultWithValidity_Throws_Error() public {
    mockSystemCoinOracle.setThrowsError(true);
    assertEq(auctionHouse.getSystemCoinMarketPrice(), 0);
  }

  function test_Return_GetResultWithValidity_ScaledToRay(uint256 _price) public {
    vm.assume(notOverflowMul(_price, 10 ** 9));
    mockSystemCoinOracle.setPriceAndValidity(_price, true);
    assertEq(auctionHouse.getSystemCoinMarketPrice(), _price * 10 ** 9);
  }
}

contract Unit_CollateralAuctionHouse_GetSystemCoinFloorDeviatedPrice is Base {
  using Math for uint256;

  struct GetSystemCoinFloorDeviatedPriceScenario {
    // Function params
    uint256 redemptionPrice;
    // contract values
    uint256 minSystemCoinDeviation;
    uint256 lowerSystemCoinDeviation;
  }

  modifier happyPath(GetSystemCoinFloorDeviatedPriceScenario memory _scenario) {
    vm.assume(notOverflowMul(_scenario.redemptionPrice, _scenario.minSystemCoinDeviation));
    vm.assume(notOverflowMul(_scenario.redemptionPrice, _scenario.lowerSystemCoinDeviation));

    _mockLowerSystemCoinMarketDeviation(_scenario.lowerSystemCoinDeviation);
    _mockMinSystemCoinMarketDeviation(_scenario.minSystemCoinDeviation);
    _;
  }

  function test_Return_FloorPrice(GetSystemCoinFloorDeviatedPriceScenario memory _scenario) public happyPath(_scenario) {
    uint256 _minFloorDeviatedPrice = _scenario.redemptionPrice.wmul(_scenario.minSystemCoinDeviation);
    uint256 _floorPrice = _scenario.redemptionPrice.wmul(_scenario.lowerSystemCoinDeviation);

    vm.assume(_floorPrice <= _minFloorDeviatedPrice);

    assertEq(auctionHouse.getSystemCoinFloorDeviatedPrice(_scenario.redemptionPrice), _floorPrice);
  }

  function test_Return_RedemptionPrice(GetSystemCoinFloorDeviatedPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    uint256 _minFloorDeviatedPrice = _scenario.redemptionPrice.wmul(_scenario.minSystemCoinDeviation);
    uint256 _floorPrice = _scenario.redemptionPrice.wmul(_scenario.lowerSystemCoinDeviation);

    vm.assume(_floorPrice > _minFloorDeviatedPrice);

    assertEq(auctionHouse.getSystemCoinFloorDeviatedPrice(_scenario.redemptionPrice), _scenario.redemptionPrice);
  }
}

contract Unit_CollateralAuctionHouse_GetSystemCoinCeilingDeviatedPrice is Base {
  using Math for uint256;

  struct GetSystemCoinCeilingDeviatedPriceScenario {
    // Function params
    uint256 redemptionPrice;
    // contract values
    uint256 minSystemCoinDeviation;
    uint256 upperSystemCoinDeviation;
  }

  modifier happyPath(GetSystemCoinCeilingDeviatedPriceScenario memory _scenario) {
    vm.assume(2 * WAD >= _scenario.upperSystemCoinDeviation);
    vm.assume(2 * WAD >= _scenario.minSystemCoinDeviation);
    vm.assume(notOverflowMul(2 * WAD - _scenario.minSystemCoinDeviation, _scenario.redemptionPrice));
    vm.assume(notOverflowMul(2 * WAD - _scenario.upperSystemCoinDeviation, _scenario.redemptionPrice));
    _;
  }

  function _mockValues(GetSystemCoinCeilingDeviatedPriceScenario memory _scenario) internal {
    _mockUpperSystemCoinMarketDeviation(_scenario.upperSystemCoinDeviation);
    _mockMinSystemCoinMarketDeviation(_scenario.minSystemCoinDeviation);
  }

  function test_Return_CeilingPrice(GetSystemCoinCeilingDeviatedPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    uint256 _minCeilingDeviatedPrice = _scenario.redemptionPrice.wmul(2 * WAD - _scenario.minSystemCoinDeviation);
    uint256 _ceilingPrice = _scenario.redemptionPrice.wmul(2 * WAD - _scenario.upperSystemCoinDeviation);

    vm.assume(_ceilingPrice >= _minCeilingDeviatedPrice);
    _mockValues(_scenario);

    assertEq(auctionHouse.getSystemCoinCeilingDeviatedPrice(_scenario.redemptionPrice), _ceilingPrice);
  }

  function test_Return_RedemptionPrice(GetSystemCoinCeilingDeviatedPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    uint256 _minCeilingDeviatedPrice = _scenario.redemptionPrice.wmul(2 * WAD - _scenario.minSystemCoinDeviation);
    uint256 _ceilingPrice = _scenario.redemptionPrice.wmul(2 * WAD - _scenario.upperSystemCoinDeviation);

    vm.assume(_ceilingPrice < _minCeilingDeviatedPrice);
    _mockValues(_scenario);

    assertEq(auctionHouse.getSystemCoinCeilingDeviatedPrice(_scenario.redemptionPrice), _scenario.redemptionPrice);
  }
}

contract Unit_CollateralAuctionHouse_GetCollateralFSMAndFinalSystemCoinPrices is Base {
  struct GetCollateralFSMAndFinalSystemCoinPricesScenario {
    // Function params
    uint256 systemCoinRedemptionPrice;
    // function return values
    uint256 collateralFsmPriceFeedValue;
    uint256 systemCoinMarketPrice;
    uint256 finalSystemCoinPrice;
  }

  function setUp() public override {
    super.setUp();
    _setCallSuper(false);
  }

  function test_Call_CollateralFSM_GetResultWithValidity(
    GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario
  ) public {
    vm.assume(_scenario.systemCoinRedemptionPrice > 0);
    vm.expectCall(address(mockCollateralFSM), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector));

    auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);
  }

  function test_Call_Internal_GetSystemCoinMarketPrice(
    GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario
  ) public {
    vm.assume(_scenario.systemCoinRedemptionPrice > 0);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector, abi.encodeWithSignature('_getSystemCoinMarketPrice()')
      )
    );

    auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);
  }

  function test_Call_Internal_GetFinalSystemCoinPrice(GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario)
    public
  {
    vm.assume(_scenario.systemCoinRedemptionPrice > 0);
    vm.assume(_scenario.systemCoinMarketPrice > 0);
    _mockGetSystemCoinMarketPrice(_scenario.systemCoinMarketPrice);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getFinalSystemCoinPrice(uint256,uint256)',
          _scenario.systemCoinRedemptionPrice,
          _scenario.systemCoinMarketPrice
        )
      )
    );

    auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);
  }

  function test_Revert_SystemCoinRedemptionPriceIsZero() public {
    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/invalid-redemption-price-provided'));

    auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(0);
  }

  function test_Return_Zero_GetResultWithValidity_NotValid(
    GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario
  ) public {
    vm.assume(_scenario.systemCoinRedemptionPrice > 0);
    vm.assume(_scenario.collateralFsmPriceFeedValue > 0);

    mockCollateralFSM.setPriceAndValidity(_scenario.collateralFsmPriceFeedValue, false);

    (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice) =
      auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);
    assertEq(_cFsmPriceFeedValue, 0);
    assertEq(_sCoinAdjustedPrice, 0);
  }

  function test_Return_SystemCoinRedemptionPrice_SystemCoinPriceFeedValue_IsZero(
    GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario
  ) public {
    vm.assume(_scenario.systemCoinRedemptionPrice > 0);
    _mockGetSystemCoinMarketPrice(0);
    _mockGetFinalSystemCoinPrice(_scenario.finalSystemCoinPrice);

    (, uint256 _sCoinAdjustedPrice) =
      auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);
    assertEq(_sCoinAdjustedPrice, _scenario.systemCoinRedemptionPrice);
  }

  function test_Return_FinalSystemCoinPrice_SystemCoinPriceFeedValue(
    GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario
  ) public {
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).setCallSupper_getFinalSystemCoinPrice(false);

    vm.assume(_scenario.systemCoinRedemptionPrice > 0);
    vm.assume(_scenario.systemCoinMarketPrice > 0);
    _mockGetSystemCoinMarketPrice(_scenario.systemCoinMarketPrice);
    _mockGetFinalSystemCoinPrice(_scenario.finalSystemCoinPrice);

    (, uint256 _sCoinAdjustedPrice) =
      auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);
    assertEq(_sCoinAdjustedPrice, _scenario.finalSystemCoinPrice);
  }

  function test_Return_CollateralFSMPriceFeedValue(GetCollateralFSMAndFinalSystemCoinPricesScenario memory _scenario)
    public
  {
    vm.assume(_scenario.systemCoinRedemptionPrice > 0);
    mockCollateralFSM.setPriceAndValidity(_scenario.collateralFsmPriceFeedValue, true);

    (uint256 _cFsmPriceFeedValue,) =
      auctionHouse.getCollateralFSMAndFinalSystemCoinPrices(_scenario.systemCoinRedemptionPrice);

    assertEq(_cFsmPriceFeedValue, _scenario.collateralFsmPriceFeedValue);
  }
}

contract Unit_CollateralAuctionHouse_GetFinalSystemCoinPrice is Base {
  struct GetFinalSystemCoinPriceScenario {
    // Function params
    uint256 systemCoinRedemptionPrice;
    uint256 systemCoinMarketPrice;
    // internal function return values
    uint256 systemCoinFloorDeviatedPrice;
    uint256 systemCoinCeilingDeviatedPrice;
  }

  function setUp() public override {
    super.setUp();
    _setCallSuper(false);
  }

  function _mockValues(GetFinalSystemCoinPriceScenario memory _scenario) internal {
    _mockGetSystemCoinFloorDeviatedPrice(_scenario.systemCoinFloorDeviatedPrice);
    _mockGetSystemCoinCeilingDeviatedPrice(_scenario.systemCoinCeilingDeviatedPrice);
  }

  function test_Call_Internal_GetSystemCoinFloorDeviatedPrice(GetFinalSystemCoinPriceScenario memory _scenario) public {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getSystemCoinFloorDeviatedPrice(uint256)', _scenario.systemCoinRedemptionPrice)
      )
    );

    auctionHouse.getFinalSystemCoinPrice(_scenario.systemCoinRedemptionPrice, _scenario.systemCoinMarketPrice);
  }

  function test_Call_Internal_GetSystemCoinCeilingDeviatedPrice(GetFinalSystemCoinPriceScenario memory _scenario)
    public
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getSystemCoinCeilingDeviatedPrice(uint256)', _scenario.systemCoinRedemptionPrice)
      )
    );

    auctionHouse.getFinalSystemCoinPrice(_scenario.systemCoinRedemptionPrice, _scenario.systemCoinMarketPrice);
  }

  function test_Return_SystemCoinMarketPrice(GetFinalSystemCoinPriceScenario memory _scenario) public {
    vm.assume(_scenario.systemCoinMarketPrice < _scenario.systemCoinRedemptionPrice);
    vm.assume(_scenario.systemCoinMarketPrice > _scenario.systemCoinFloorDeviatedPrice);

    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalSystemCoinPrice(_scenario.systemCoinRedemptionPrice, _scenario.systemCoinMarketPrice),
      _scenario.systemCoinMarketPrice
    );
  }

  function test_Return_SystemCoinFloorDeviatedPrice(GetFinalSystemCoinPriceScenario memory _scenario) public {
    vm.assume(_scenario.systemCoinMarketPrice < _scenario.systemCoinRedemptionPrice);
    vm.assume(_scenario.systemCoinMarketPrice <= _scenario.systemCoinFloorDeviatedPrice);

    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalSystemCoinPrice(_scenario.systemCoinRedemptionPrice, _scenario.systemCoinMarketPrice),
      _scenario.systemCoinFloorDeviatedPrice
    );
  }

  function test_Return_SystemCoinMarketPrice_LtCeilingPrice(GetFinalSystemCoinPriceScenario memory _scenario) public {
    vm.assume(_scenario.systemCoinMarketPrice >= _scenario.systemCoinRedemptionPrice);
    vm.assume(_scenario.systemCoinMarketPrice < _scenario.systemCoinCeilingDeviatedPrice);

    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalSystemCoinPrice(_scenario.systemCoinRedemptionPrice, _scenario.systemCoinMarketPrice),
      _scenario.systemCoinMarketPrice
    );
  }

  function test_Return_SystemCoinCeilingDeviatedPrice(GetFinalSystemCoinPriceScenario memory _scenario) public {
    vm.assume(_scenario.systemCoinMarketPrice >= _scenario.systemCoinRedemptionPrice);
    vm.assume(_scenario.systemCoinMarketPrice >= _scenario.systemCoinCeilingDeviatedPrice);

    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalSystemCoinPrice(_scenario.systemCoinRedemptionPrice, _scenario.systemCoinMarketPrice),
      _scenario.systemCoinCeilingDeviatedPrice
    );
  }
}

contract Unit_CollateralAuctionHouse_GetFinalBaseCollateralPrice is Base {
  using Math for uint256;

  struct GetFinalBaseCollateralPriceScenario {
    // Function params
    uint256 collateralFsmPriceFeedValue;
    uint256 collateralMarketPriceFeedValue;
    // Contract values
    uint256 lowerCollateralDeviation;
    uint256 upperCollateralDeviation;
  }

  function _mockValues(GetFinalBaseCollateralPriceScenario memory _scenario) internal {
    _mockLowerCollateralMarketDeviation(_scenario.lowerCollateralDeviation);
    _mockUpperCollateralMarketDeviation(_scenario.upperCollateralDeviation);
  }

  modifier happyPath(GetFinalBaseCollateralPriceScenario memory _scenario) {
    vm.assume(notOverflowMul(_scenario.collateralFsmPriceFeedValue, _scenario.lowerCollateralDeviation));
    vm.assume(2 * WAD > _scenario.upperCollateralDeviation);
    vm.assume(notOverflowMul(_scenario.collateralFsmPriceFeedValue, 2 * WAD - _scenario.upperCollateralDeviation));
    _;
  }

  function test_Return_CollateralFsmPriceFeedValue(GetFinalBaseCollateralPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.assume(
      _scenario.collateralFsmPriceFeedValue
        < _scenario.collateralFsmPriceFeedValue.wmul((2 * WAD) - _scenario.upperCollateralDeviation)
    );
    _scenario.collateralMarketPriceFeedValue = 0;
    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalBaseCollateralPrice(
        _scenario.collateralFsmPriceFeedValue, _scenario.collateralMarketPriceFeedValue
      ),
      _scenario.collateralFsmPriceFeedValue
    );
  }

  function test_Return_CeilingPrice(GetFinalBaseCollateralPriceScenario memory _scenario) public happyPath(_scenario) {
    uint256 _ceilingPrice = _scenario.collateralFsmPriceFeedValue.wmul((2 * WAD) - _scenario.upperCollateralDeviation);
    vm.assume(_scenario.collateralFsmPriceFeedValue >= _ceilingPrice);
    _scenario.collateralMarketPriceFeedValue = 0;
    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalBaseCollateralPrice(
        _scenario.collateralFsmPriceFeedValue, _scenario.collateralMarketPriceFeedValue
      ),
      _ceilingPrice
    );
  }

  function test_Return_CollateralMarketPriceFeedValue(GetFinalBaseCollateralPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.assume(_scenario.collateralMarketPriceFeedValue > 0);
    vm.assume(_scenario.collateralMarketPriceFeedValue < _scenario.collateralFsmPriceFeedValue);
    vm.assume(
      _scenario.collateralMarketPriceFeedValue
        >= _scenario.collateralFsmPriceFeedValue.wmul(_scenario.lowerCollateralDeviation)
    );

    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalBaseCollateralPrice(
        _scenario.collateralFsmPriceFeedValue, _scenario.collateralMarketPriceFeedValue
      ),
      _scenario.collateralMarketPriceFeedValue
    );
  }

  function test_Return_FloorPrice(GetFinalBaseCollateralPriceScenario memory _scenario) public happyPath(_scenario) {
    vm.assume(_scenario.collateralMarketPriceFeedValue > 0);
    vm.assume(_scenario.collateralMarketPriceFeedValue < _scenario.collateralFsmPriceFeedValue);
    uint256 _floorPrice = _scenario.collateralFsmPriceFeedValue.wmul(_scenario.lowerCollateralDeviation);
    vm.assume(_scenario.collateralMarketPriceFeedValue < _floorPrice);

    _mockValues(_scenario);

    assertEq(
      auctionHouse.getFinalBaseCollateralPrice(
        _scenario.collateralFsmPriceFeedValue, _scenario.collateralMarketPriceFeedValue
      ),
      _floorPrice
    );
  }
}

contract Unit_CollateralAuctionHouse_GetDiscountedCollateralPrice is Base {
  using Math for uint256;

  struct GetDiscountedCollateralPriceScenario {
    // Function params
    uint256 collateralFsmPriceFeedValue;
    uint256 collateralMarketPriceFeedValue;
    uint256 systemCoinPriceFeedValue;
    uint256 customDiscount;
    // Internal function return value
    uint256 finalBaseCollateralPrice;
  }

  function setUp() public override {
    super.setUp();
    _setCallSuper(false);
  }

  modifier happyPath(GetDiscountedCollateralPriceScenario memory _scenario) {
    vm.assume(_scenario.systemCoinPriceFeedValue > 0);
    vm.assume(notOverflowMul(_scenario.finalBaseCollateralPrice, RAY));
    vm.assume(
      notOverflowMul(
        _scenario.finalBaseCollateralPrice.rdiv(_scenario.systemCoinPriceFeedValue), _scenario.customDiscount
      )
    );
    _;
  }

  function _mockValues(GetDiscountedCollateralPriceScenario memory _scenario) internal {
    _mockGetFinalBaseCollateralPrice(_scenario.finalBaseCollateralPrice);
  }

  function test_Call_Internal_GetFinalBaseCollateralPrice(GetDiscountedCollateralPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    _mockGetFinalBaseCollateralPrice(_scenario.finalBaseCollateralPrice);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getFinalBaseCollateralPrice(uint256,uint256)',
          _scenario.collateralFsmPriceFeedValue,
          _scenario.collateralMarketPriceFeedValue
        )
      )
    );

    auctionHouse.getDiscountedCollateralPrice(
      _scenario.collateralFsmPriceFeedValue,
      _scenario.collateralMarketPriceFeedValue,
      _scenario.systemCoinPriceFeedValue,
      _scenario.customDiscount
    );
  }

  function test_Return_DiscountedCollateralPrice(GetDiscountedCollateralPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    _mockGetFinalBaseCollateralPrice(_scenario.finalBaseCollateralPrice);

    uint256 _expectedResult =
      _scenario.finalBaseCollateralPrice.rdiv(_scenario.systemCoinPriceFeedValue).wmul(_scenario.customDiscount);

    assertEq(
      auctionHouse.getDiscountedCollateralPrice(
        _scenario.collateralFsmPriceFeedValue,
        _scenario.collateralMarketPriceFeedValue,
        _scenario.systemCoinPriceFeedValue,
        _scenario.customDiscount
      ),
      _expectedResult
    );
  }
}

contract Unit_CollateralAuctionHouse_GetNextCurrentDiscount is Base {
  using Math for uint256;

  address nonNullForgoneCollateralReceiver = label('nonNullForgoneCollateralReceiver');

  struct GetNextCurrentDiscountScenario {
    uint48 timestamp;
    // bid values
    uint256 currentDiscount;
    uint256 maxDiscount;
    uint256 perSecondDiscountUpdateRate;
    uint256 latestDiscountUpdateTime;
  }

  function _mockValues(GetNextCurrentDiscountScenario memory _scenario, address _forgoneCollateralReceiver) internal {
    vm.warp(_scenario.timestamp);

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: 0,
        amountToRaise: 0,
        currentDiscount: _scenario.currentDiscount,
        maxDiscount: _scenario.maxDiscount,
        perSecondDiscountUpdateRate: _scenario.perSecondDiscountUpdateRate,
        latestDiscountUpdateTime: _scenario.latestDiscountUpdateTime,
        forgoneCollateralReceiver: _forgoneCollateralReceiver,
        auctionIncomeRecipient: address(0)
      })
    );
  }

  // If the current discount is not at or greater than max
  function _currentDiscountNotGtThanMax(GetNextCurrentDiscountScenario memory _scenario) internal pure returns (bool) {
    vm.assume(_scenario.timestamp >= _scenario.latestDiscountUpdateTime);
    return _scenario.currentDiscount > _scenario.maxDiscount;
  }

  function _notOverflows(GetNextCurrentDiscountScenario memory _scenario) internal view {
    vm.assume(
      notOverflowRPow(_scenario.perSecondDiscountUpdateRate, _scenario.timestamp - _scenario.latestDiscountUpdateTime)
    );
    vm.assume(
      notOverflowMul(
        _scenario.perSecondDiscountUpdateRate.rpow(_scenario.timestamp - _scenario.latestDiscountUpdateTime),
        _scenario.currentDiscount
      )
    );
  }

  function test_Return_RAY(GetNextCurrentDiscountScenario memory _scenario) public {
    _mockValues(_scenario, address(0));
    assertEq(auctionHouse.getNextCurrentDiscount(1), RAY);
  }

  function test_Return_NextDiscount_CurrentDiscountNotGtThanMax_And_NextDiscountGtMax(
    GetNextCurrentDiscountScenario memory _scenario
  ) public {
    vm.assume(_currentDiscountNotGtThanMax(_scenario));
    _notOverflows(_scenario);

    uint256 _nextDiscount = _scenario.perSecondDiscountUpdateRate.rpow(
      _scenario.timestamp - _scenario.latestDiscountUpdateTime
    ).rmul(_scenario.currentDiscount);

    vm.assume(_nextDiscount > _scenario.maxDiscount);

    _mockValues(_scenario, nonNullForgoneCollateralReceiver);

    assertEq(auctionHouse.getNextCurrentDiscount(1), _nextDiscount);
  }

  function test_Return_MaxDiscount_CurrentDiscountNotGtThanMax_And_NextDiscountNotGtMax(
    GetNextCurrentDiscountScenario memory _scenario
  ) public {
    vm.assume(_currentDiscountNotGtThanMax(_scenario));
    _notOverflows(_scenario);

    uint256 _nextDiscount = _scenario.perSecondDiscountUpdateRate.rpow(
      _scenario.timestamp - _scenario.latestDiscountUpdateTime
    ).rmul(_scenario.currentDiscount);

    vm.assume(_nextDiscount <= _scenario.maxDiscount);

    _mockValues(_scenario, nonNullForgoneCollateralReceiver);

    assertEq(auctionHouse.getNextCurrentDiscount(1), _scenario.maxDiscount);
  }
}

contract Unit_CollateralAuctionHouse_GetAdjustedBid is Base {
  struct GetAdjustedBidScenario {
    // Function parameter
    uint256 wad;
    // Contract values
    uint256 minimumBid;
    // Bid values
    uint256 amountToSell;
    uint256 amountToRaise;
  }

  function _mockValues(GetAdjustedBidScenario memory _scenario) internal {
    _mockMinimumBid(_scenario.minimumBid);

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _scenario.amountToSell,
        amountToRaise: _scenario.amountToRaise,
        currentDiscount: 0,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );
  }

  function _happyPath(GetAdjustedBidScenario memory _scenario) internal pure {
    vm.assume(_scenario.amountToSell > 0);
    vm.assume(_scenario.amountToRaise > 0);
    vm.assume(_scenario.wad > 0);
    vm.assume(_scenario.wad >= _scenario.minimumBid);
    vm.assume(notOverflowMul(_scenario.wad, RAY));
  }

  function test_Return_WadAndNotValid_AmountToSellIsZero(GetAdjustedBidScenario memory _scenario) public {
    _scenario.amountToSell = 0;
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _scenario.wad);
    assertFalse(_valid);
  }

  function test_Return_WadAndNotValid_AmountToRaiseIsZero(GetAdjustedBidScenario memory _scenario) public {
    _scenario.amountToRaise = 0;
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _scenario.wad);
    assertFalse(_valid);
  }

  function test_Return_WadAndNotValid_WadIsZero(GetAdjustedBidScenario memory _scenario) public {
    _scenario.wad = 0;
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _scenario.wad);
    assertFalse(_valid);
  }

  function test_Return_WadAndNotValid_WadLtMinBid(GetAdjustedBidScenario memory _scenario) public {
    vm.assume(_scenario.wad < _scenario.minimumBid);
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _scenario.wad);
    assertFalse(_valid);
  }

  function test_Return_WadAndValid(GetAdjustedBidScenario memory _scenario) public {
    _happyPath(_scenario);
    vm.assume(_scenario.wad * RAY <= _scenario.amountToRaise);
    vm.assume(_scenario.amountToRaise - _scenario.wad * RAY >= RAY);
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _scenario.wad);
    assertTrue(_valid);
  }

  /*
  // Rejected more than 1000000 inputs
  function test_Return_WadAndNotValid(GetAdjustedBidScenario memory _scenario) public {
    _happyPath(_scenario);
    vm.assume(_scenario.wad * RAY <= _scenario.amountToRaise);
    vm.assume(_scenario.amountToRaise - _scenario.wad * RAY < RAY);
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _scenario.wad);
    assertFalse(_valid);
  }
  */

  function test_Return_AdjustedBidAndValid(GetAdjustedBidScenario memory _scenario) public {
    _happyPath(_scenario);
    vm.assume(_scenario.wad * RAY > _scenario.amountToRaise);
    uint256 _expectedAdjustedBid = _scenario.amountToRaise / RAY + 1;
    vm.assume(_expectedAdjustedBid * RAY >= _scenario.amountToRaise);

    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _expectedAdjustedBid);
    assertTrue(_valid);
  }

  /*
  // Rejected more than 1000000 inputs
  function test_Return_AdjustedBidAndNotValid(GetAdjustedBidScenario memory _scenario) public {
    _happyPath(_scenario);
    vm.assume(_scenario.wad * RAY > _scenario.amountToRaise);
    uint256 _expectedAdjustedBid = _scenario.amountToRaise / RAY + 1;
    vm.assume(_expectedAdjustedBid * RAY < _scenario.amountToRaise);
    //Also missing assumption where => _scenario.amountToRaise - _expectedAdjustedBid * RAY < RAY which generates even more rejections 
    
    _mockValues(_scenario);

    (bool _valid, uint256 _adjustedBid) = auctionHouse.getAdjustedBid(1, _scenario.wad);
    assertEq(_adjustedBid, _expectedAdjustedBid);
    assertTrue(_valid);
  }
  */
}

contract Unit_CollateralAuctionHouse_StartAuction is Base {
  address forgoneCollateralReceiver = label('forgoneCollateralReceiver');
  address auctionIncomeRecipient = label('auctionIncomeRecipient');

  event StartAuction(
    uint256 _id,
    uint256 _auctionsStarted,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 indexed _amountToRaise,
    uint256 _startingDiscount,
    uint256 _maxDiscount,
    uint256 _perSecondDiscountUpdateRate,
    address indexed _forgoneCollateralReceiver,
    address indexed _auctionIncomeRecipient
  );

  struct StartAuctionScenario {
    // Contract values
    uint256 minDiscount;
    uint256 maxDiscount;
    uint256 perSecondDiscountUpdateRate;
    uint256 auctionsStarted;
    // Function parameters
    uint256 amountToRaise;
    uint256 amountToSell;
    uint256 initialBid; // NOTE: ignored, only used in event
  }

  function _mockValues(StartAuctionScenario memory _scenario) internal {
    _mockMinDiscount(_scenario.minDiscount);
    _mockMaxDiscount(_scenario.maxDiscount);
    _mockAuctionsStarted(_scenario.auctionsStarted);

    _mockPerSecondDiscountUpdateRate(_scenario.perSecondDiscountUpdateRate);
    _mockSafeEngineTransferCollateralStartAuction(_scenario.amountToSell);
  }

  function _amountSellNotZero(StartAuctionScenario memory _scenario) internal pure returns (bool) {
    return _scenario.amountToSell > 0;
  }

  function _amountToRaiseNotZero(StartAuctionScenario memory _scenario) internal pure returns (bool) {
    return _scenario.amountToRaise > 0;
  }

  function _amountToRaiseGtEqRay(StartAuctionScenario memory _scenario) internal pure returns (bool) {
    return _scenario.amountToRaise >= RAY;
  }

  modifier happyPath(StartAuctionScenario memory _scenario) {
    vm.assume(_scenario.auctionsStarted < type(uint256).max);
    vm.assume(_amountSellNotZero(_scenario));
    vm.assume(_amountToRaiseNotZero(_scenario));
    vm.assume(_amountToRaiseGtEqRay(_scenario));

    _mockValues(_scenario);
    _;
  }

  function test_Set_AuctionStarted(StartAuctionScenario memory _scenario) public happyPath(_scenario) authorized {
    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );

    assertEq(auctionHouse.auctionsStarted(), _scenario.auctionsStarted + 1);
  }

  function test_Call_SafeEngine_TransferCollateral(StartAuctionScenario memory _scenario)
    public
    happyPath(_scenario)
    authorized
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector,
        mockCollateralType,
        deployer,
        address(auctionHouse),
        _scenario.amountToSell
      )
    );

    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );
  }

  function test_Create_Bid(StartAuctionScenario memory _scenario) public happyPath(_scenario) authorized {
    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );

    IIncreasingDiscountCollateralAuctionHouse.Auction memory _auction =
      auctionHouse.auctions(_scenario.auctionsStarted + 1);

    bytes memory _expectedBid = abi.encode(
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.minDiscount,
      _scenario.maxDiscount,
      _scenario.perSecondDiscountUpdateRate,
      block.timestamp,
      forgoneCollateralReceiver,
      auctionIncomeRecipient
    );

    bytes memory _createdBid = abi.encode(
      _auction.amountToRaise,
      _auction.amountToSell,
      _auction.currentDiscount,
      _auction.maxDiscount,
      _auction.perSecondDiscountUpdateRate,
      _auction.latestDiscountUpdateTime,
      _auction.forgoneCollateralReceiver,
      _auction.auctionIncomeRecipient
    );

    assertEq(_createdBid, _expectedBid);
  }

  function test_Emit_StartAuction(StartAuctionScenario memory _scenario) public happyPath(_scenario) authorized {
    vm.expectEmit(true, false, false, true);

    emit StartAuction({
      _id: _scenario.auctionsStarted + 1,
      _auctionsStarted: _scenario.auctionsStarted + 1,
      _amountToSell: _scenario.amountToSell,
      _initialBid: _scenario.initialBid,
      _amountToRaise: _scenario.amountToRaise,
      _startingDiscount: _scenario.minDiscount,
      _maxDiscount: _scenario.maxDiscount,
      _perSecondDiscountUpdateRate: _scenario.perSecondDiscountUpdateRate,
      _forgoneCollateralReceiver: forgoneCollateralReceiver,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );
  }

  function test_Revert_NotAuthorized(StartAuctionScenario memory _scenario) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );
  }

  function test_Revert_AmountToSellIsZero(StartAuctionScenario memory _scenario) public authorized {
    _scenario.amountToSell = 0;
    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/no-collateral-for-sale'));

    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );
  }

  function test_Revert_AmountToRaiseIsZero(StartAuctionScenario memory _scenario) public authorized {
    vm.assume(_amountSellNotZero(_scenario));
    _scenario.amountToRaise = 0;
    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/nothing-to-raise'));

    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );
  }

  function test_Revert_AmountToRaiseDustyAuction(StartAuctionScenario memory _scenario) public authorized {
    vm.assume(_amountSellNotZero(_scenario));
    vm.assume(_amountToRaiseNotZero(_scenario));
    vm.assume(!_amountToRaiseGtEqRay(_scenario));
    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/dusty-auction'));

    auctionHouse.startAuction(
      forgoneCollateralReceiver,
      auctionIncomeRecipient,
      _scenario.amountToRaise,
      _scenario.amountToSell,
      _scenario.initialBid
    );
  }
}

contract Unit_CollateralAuctionHouse_GetApproximateCollateralBought is Base {
  struct GetApproximateCollateralBoughtScenario {
    // Function parameters
    uint256 id;
    uint256 wad;
    // Contract values
    uint256 lastReadRedemptionPrice;
    // Internal function return values
    uint256 adjustedBid;
    uint256 collateralFsmPriceFeedValue;
    uint256 systemCoinPriceFeedValue;
    uint256 collateralMarketPrice;
    uint256 currentDiscount;
    uint256 boughtCollateral;
  }

  function setUp() public override {
    super.setUp();
    _setCallSuper(false);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse))
      .setCallSupper_getCollateralFSMAndFinalSystemCoinPrices(false);
  }

  function _mockValues(GetApproximateCollateralBoughtScenario memory _scenario, bool _validAuctionAndBid) internal {
    _mockGetAdjustedBid(_validAuctionAndBid, _scenario.adjustedBid);
    _mockGetCollateralFSMAndFinalSystemCoinPrices(
      _scenario.collateralFsmPriceFeedValue, _scenario.systemCoinPriceFeedValue
    );
    _mockLastReadRedemptionPrice(_scenario.lastReadRedemptionPrice);
    _mockGetCollateralMarketPrice(_scenario.collateralMarketPrice);
    if (_scenario.id > 1) {
      _mockAuctionsStarted(_scenario.id - 1);
    }

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: 0,
        amountToRaise: 0,
        currentDiscount: _scenario.currentDiscount,
        maxDiscount: 0,
        perSecondDiscountUpdateRate: 0,
        latestDiscountUpdateTime: 0,
        forgoneCollateralReceiver: address(0),
        auctionIncomeRecipient: address(0)
      })
    );
  }

  modifier happyPath(GetApproximateCollateralBoughtScenario memory _scenario) {
    vm.assume(_scenario.id > 0);
    vm.assume(_scenario.lastReadRedemptionPrice > 0);
    vm.assume(_scenario.collateralFsmPriceFeedValue > 0);
    _mockValues(_scenario, true);
    _;
  }

  function test_Return_ZeroBoughtCollateralIdAndWad(GetApproximateCollateralBoughtScenario memory _scenario) public {
    _scenario.lastReadRedemptionPrice = 0;
    _mockValues(_scenario, true);

    (uint256 _boughtCollateral, uint256 _adjustedBid) =
      auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);
    assertEq(abi.encode(_boughtCollateral, _adjustedBid), abi.encode(0, _scenario.wad));
  }

  function test_Return_ZeroBoughtCollateralIdAndAdjustedBid_NotValidAuctionAndBid(
    GetApproximateCollateralBoughtScenario memory _scenario
  ) public {
    vm.assume(_scenario.lastReadRedemptionPrice > 0);

    _mockValues(_scenario, false);

    (uint256 _boughtCollateral, uint256 _adjustedBid) =
      auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);

    assertEq(abi.encode(_boughtCollateral, _adjustedBid), abi.encode(0, _scenario.adjustedBid));
  }

  function test_Return_ZeroBoughtCollateralIdAndAdjustedBid_CollateralFsmPriceFeedValueIsZero(
    GetApproximateCollateralBoughtScenario memory _scenario
  ) public {
    vm.assume(_scenario.lastReadRedemptionPrice > 0);
    _scenario.collateralFsmPriceFeedValue = 0;

    _mockValues(_scenario, true);

    (uint256 _boughtCollateral, uint256 _adjustedBid) =
      auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);

    assertEq(abi.encode(_boughtCollateral, _adjustedBid), abi.encode(0, _scenario.adjustedBid));
  }

  function test_Call_Internal_GetAdjustedBid(GetApproximateCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getAdjustedBid(uint256,uint256)', _scenario.id, _scenario.wad)
      )
    );

    auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetCollateralFSMAndFinalSystemCoinPrices(
    GetApproximateCollateralBoughtScenario memory _scenario
  ) public happyPath(_scenario) {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getCollateralFSMAndFinalSystemCoinPrices(uint256)', _scenario.lastReadRedemptionPrice)
      )
    );

    auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetCollateralMarketPrice(GetApproximateCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector, abi.encodeWithSignature('_getCollateralMarketPrice()')
      )
    );

    auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetBoughtCollateral(GetApproximateCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getBoughtCollateral(uint256,uint256,uint256,uint256,uint256,uint256)',
          _scenario.id,
          _scenario.collateralFsmPriceFeedValue,
          _scenario.collateralMarketPrice,
          _scenario.systemCoinPriceFeedValue,
          _scenario.adjustedBid,
          _scenario.currentDiscount
        )
      )
    );

    auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Return_BoughtCollateralAndAdjustedBid(GetApproximateCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    _mockGetBoughtCollateral(_scenario.boughtCollateral);
    (uint256 _boughtCollateral, uint256 _adjustedBid) =
      auctionHouse.getApproximateCollateralBought(_scenario.id, _scenario.wad);
    assertEq(abi.encode(_boughtCollateral, _adjustedBid), abi.encode(_scenario.boughtCollateral, _scenario.adjustedBid));
  }
}

contract Unit_CollateralAuction_GetCollateralBought is Base {
  function setUp() public override {
    super.setUp();
    _setCallSuper(false);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse))
      .setCallSupper_getCollateralFSMAndFinalSystemCoinPrices(false);
  }

  struct GetCollateralBoughtScenario {
    // Function parameters
    uint256 id;
    uint256 wad;
    // External function return values
    uint256 oracleRedemptionPrice;
    // Internal function return values
    uint256 adjustedBid;
    uint256 collateralFsmPriceFeedValue;
    uint256 systemCoinPriceFeedValue;
    uint256 collateralMarketPrice;
    uint256 currentDiscount;
  }

  function _mockValues(GetCollateralBoughtScenario memory _scenario, bool _validAuctionAndBid) internal {
    _mockGetAdjustedBid(_validAuctionAndBid, _scenario.adjustedBid);
    _mockGetCollateralFSMAndFinalSystemCoinPrices(
      _scenario.collateralFsmPriceFeedValue, _scenario.systemCoinPriceFeedValue
    );
    _mockOracleRelayerRedemptionPrice(_scenario.oracleRedemptionPrice);

    _mockGetCollateralMarketPrice(_scenario.collateralMarketPrice);
    _mockUpdateCurrentDiscount(_scenario.currentDiscount);
  }

  modifier happyPath(GetCollateralBoughtScenario memory _scenario) {
    vm.assume(_scenario.collateralFsmPriceFeedValue > 0);
    _mockValues(_scenario, true);
    _;
  }

  function test_Return_ZeroBoughtCollateralAndAdjustedBid(GetCollateralBoughtScenario memory _scenario) public {
    _mockValues(_scenario, false);

    (uint256 _boughtCollateral, uint256 _adjustedBid) = auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
    assertEq(abi.encode(_boughtCollateral, _adjustedBid), abi.encode(0, _scenario.adjustedBid));
  }

  function test_Return_ZeroBoughtCollateralAndAdjustedBid_CollateralFsmPriceFeedValueIsZero(
    GetCollateralBoughtScenario memory _scenario
  ) public {
    _scenario.collateralFsmPriceFeedValue = 0;
    _mockValues(_scenario, true);

    (uint256 _boughtCollateral, uint256 _adjustedBid) = auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
    assertEq(abi.encode(_boughtCollateral, _adjustedBid), abi.encode(0, _scenario.adjustedBid));
  }

  function test_Call_Internal_GetAdjustedBid(GetCollateralBoughtScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getAdjustedBid(uint256,uint256)', _scenario.id, _scenario.wad)
      )
    );

    auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_OracleRelayer_RedemptionPrice(GetCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector));

    auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetCollateralFSMAndFinalSystemCoinPrices(GetCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getCollateralFSMAndFinalSystemCoinPrices(uint256)', _scenario.oracleRedemptionPrice)
      )
    );

    auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetCollateralMarketPrice(GetCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector, abi.encodeWithSignature('_getCollateralMarketPrice()')
      )
    );

    auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_UpdateCurrentDiscount(GetCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_updateCurrentDiscount(uint256)', _scenario.id)
      )
    );

    auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetBoughtCollateral(GetCollateralBoughtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getBoughtCollateral(uint256,uint256,uint256,uint256,uint256,uint256)',
          _scenario.id,
          _scenario.collateralFsmPriceFeedValue,
          _scenario.collateralMarketPrice,
          _scenario.systemCoinPriceFeedValue,
          _scenario.adjustedBid,
          _scenario.currentDiscount
        )
      )
    );

    auctionHouse.getCollateralBought(_scenario.id, _scenario.wad);
  }
}

contract Unit_CollateralAuctionHouse_BuyCollateral is Base {
  address auctionIncomeRecipient = label('auctionIncomeRecipient');
  address forgoneCollateralReceiver = label('forgoneCollateralReceiver');

  function setUp() public override {
    super.setUp();
    _setCallSuper(false);
    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse))
      .setCallSupper_getCollateralFSMAndFinalSystemCoinPrices(false);
    vm.startPrank(deployer);
  }

  struct BuyCollateralScenario {
    // Function parameters
    uint256 id;
    uint256 wad;
    // Bid values
    uint256 amountToSell;
    uint256 amountToRaise;
    // Contract values
    uint256 minimumBid;
    // External calls return values
    uint256 oracleRedemptionPrice;
    uint256 collateralFsmPriceFeedValue;
    uint256 systemCoinPriceFeedValue;
    uint256 boughtCollateral;
    uint256 collateralMarketPrice;
    uint256 discountUpdated;
  }

  function _mockValues(BuyCollateralScenario memory _scenario) internal {
    if (_scenario.id > 1) {
      _mockAuctionsStarted(_scenario.id - 1);
    }

    IncreasingDiscountCollateralAuctionHouseForTest(address(auctionHouse)).mock_pushBid(
      IIncreasingDiscountCollateralAuctionHouse.Auction({
        amountToSell: _scenario.amountToSell,
        amountToRaise: _scenario.amountToRaise,
        currentDiscount: 1,
        maxDiscount: 1,
        perSecondDiscountUpdateRate: 1,
        latestDiscountUpdateTime: 1,
        forgoneCollateralReceiver: forgoneCollateralReceiver,
        auctionIncomeRecipient: auctionIncomeRecipient
      })
    );

    _mockMinimumBid(_scenario.minimumBid);
    _mockOracleRelayerRedemptionPrice(_scenario.oracleRedemptionPrice);
    _mockGetCollateralFSMAndFinalSystemCoinPrices(
      _scenario.collateralFsmPriceFeedValue, _scenario.systemCoinPriceFeedValue
    );
    _mockGetBoughtCollateral(_scenario.boughtCollateral);
    _mockGetCollateralMarketPrice(_scenario.collateralMarketPrice);
    _mockUpdateCurrentDiscount(_scenario.discountUpdated);
    _mockSafeEngineTransferInternalCoins();
    _mockSafeEngineTransferCollateral(deployer, _scenario.boughtCollateral);
    _mockLiquidationEngineRemoveCoinsFromAuction();
  }

  // requires for no revert
  function _existentAuction(BuyCollateralScenario memory _scenario) internal pure returns (bool) {
    return _scenario.amountToSell > 0 && _scenario.amountToRaise > 0;
  }

  function _validBid(BuyCollateralScenario memory _scenario) internal pure returns (bool) {
    return _scenario.wad > 0 && _scenario.wad >= _scenario.minimumBid;
  }

  function _collateralFsmValidValue(BuyCollateralScenario memory _scenario) internal pure returns (bool) {
    return _scenario.collateralFsmPriceFeedValue > 0;
  }

  function _boughtCollateralNotNull(BuyCollateralScenario memory _scenario) internal pure returns (bool) {
    return _scenario.boughtCollateral > 0;
  }

  // extra paths
  function _boundMaxOffered(BuyCollateralScenario memory _scenario) internal pure returns (bool) {
    return _scenario.wad * RAY > _scenario.amountToRaise;
  }

  function _shouldUpdateAmountToRaise(BuyCollateralScenario memory _scenario) internal pure returns (bool) {
    // should update remainingToRaise in case amountToSell is zero (everything has been sold)
    uint256 _amountToSell = _scenario.amountToSell - _scenario.boughtCollateral;
    return _scenario.wad * RAY >= _scenario.amountToRaise || _amountToSell == 0;
  }

  function _updateLeftOver(BuyCollateralScenario memory _scenario, uint256 _adjustedBid) internal pure returns (bool) {
    return _adjustedBid * RAY > _scenario.amountToRaise;
  }

  function _happyPath(BuyCollateralScenario memory _scenario) internal pure {
    vm.assume(_scenario.id > 0);
    vm.assume(_existentAuction(_scenario));
    vm.assume(_validBid(_scenario));
    vm.assume(_collateralFsmValidValue(_scenario));
    vm.assume(_boughtCollateralNotNull(_scenario));
    vm.assume(_scenario.amountToSell >= _scenario.boughtCollateral);
    vm.assume(notOverflowMul(_scenario.wad, RAY));
  }

  // Happy path remaining amount to raise is zero
  modifier soldAll(BuyCollateralScenario memory _scenario) {
    _happyPath(_scenario);

    vm.assume(_boundMaxOffered(_scenario));
    vm.assume(_shouldUpdateAmountToRaise(_scenario));
    uint256 _adjustedBid = _scenario.amountToRaise / RAY + 1;
    vm.assume(_updateLeftOver(_scenario, _adjustedBid));

    _mockValues(_scenario);
    _;
  }

  // Happy path remaining amount to raise is not zero
  modifier notSoldAll(BuyCollateralScenario memory _scenario) {
    _happyPath(_scenario);
    vm.assume((_scenario.amountToRaise > _scenario.wad * RAY && _scenario.amountToRaise - _scenario.wad * RAY >= RAY));

    vm.assume(!_boundMaxOffered(_scenario));
    vm.assume(!_shouldUpdateAmountToRaise(_scenario));
    vm.assume(!_updateLeftOver(_scenario, _scenario.wad));

    _mockValues(_scenario);
    _;
  }

  modifier happyPath(BuyCollateralScenario memory _scenario) {
    _happyPath(_scenario);
    uint256 _adjustedBid = _scenario.wad;
    if (_scenario.wad * RAY > _scenario.amountToRaise) {
      _adjustedBid = _scenario.amountToRaise / RAY + 1;
    }
    uint256 _amountToRaise =
      _adjustedBid * RAY > _scenario.amountToRaise ? 0 : _scenario.amountToRaise - _adjustedBid * RAY;

    vm.assume(_amountToRaise == 0 || _amountToRaise >= RAY);

    _mockValues(_scenario);
    _;
  }

  function test_Call_OracleRelayer_RedemptionPrice(BuyCollateralScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector));

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetCollateralFSMAndFinalSystemCoinPrices(BuyCollateralScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getCollateralFSMAndFinalSystemCoinPrices(uint256)', _scenario.oracleRedemptionPrice)
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetCollateralMarketPrice(BuyCollateralScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector, abi.encodeWithSignature('_getCollateralMarketPrice()')
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_UpdateCurrentDiscount(BuyCollateralScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_updateCurrentDiscount(uint256)', _scenario.id)
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetBoughtCollateral(BuyCollateralScenario memory _scenario) public soldAll(_scenario) {
    uint256 _adjustedBid = _scenario.amountToRaise / RAY + 1;
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getBoughtCollateral(uint256,uint256,uint256,uint256,uint256,uint256)',
          _scenario.id,
          _scenario.collateralFsmPriceFeedValue,
          _scenario.collateralMarketPrice,
          _scenario.systemCoinPriceFeedValue,
          _adjustedBid,
          _scenario.discountUpdated
        )
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_Internal_GetBoughtCollateral_NotSoldAll(BuyCollateralScenario memory _scenario)
    public
    notSoldAll(_scenario)
  {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getBoughtCollateral(uint256,uint256,uint256,uint256,uint256,uint256)',
          _scenario.id,
          _scenario.collateralFsmPriceFeedValue,
          _scenario.collateralMarketPrice,
          _scenario.systemCoinPriceFeedValue,
          _scenario.wad,
          _scenario.discountUpdated
        )
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_SafeEngine_TransferInternalCoins(BuyCollateralScenario memory _scenario) public soldAll(_scenario) {
    uint256 _adjustedBid = _scenario.amountToRaise / RAY + 1;
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector, deployer, auctionIncomeRecipient, _adjustedBid * RAY
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_SafeEngine_TransferInternalCoins_NotSoldAll(BuyCollateralScenario memory _scenario)
    public
    notSoldAll(_scenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector, deployer, auctionIncomeRecipient, _scenario.wad * RAY
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_SafeEngine_TransferCollateral(BuyCollateralScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector,
        mockCollateralType,
        address(auctionHouse),
        deployer,
        _scenario.boughtCollateral
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_LiquidationEngine_RemoveCoinsFromAuction(BuyCollateralScenario memory _scenario)
    public
    soldAll(_scenario)
  {
    vm.expectCall(
      address(mockLiquidationEngine),
      abi.encodeWithSelector(ILiquidationEngine.removeCoinsFromAuction.selector, _scenario.amountToRaise)
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_LiquidationEngine_RemoveCoinsFromAuction_NotSoldAll(BuyCollateralScenario memory _scenario)
    public
    notSoldAll(_scenario)
  {
    vm.expectCall(
      address(mockLiquidationEngine),
      abi.encodeWithSelector(ILiquidationEngine.removeCoinsFromAuction.selector, _scenario.wad * RAY)
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Call_SafeEngine_TransferCollateral_SendRemainingCollateralToForgoneReceiver(
    BuyCollateralScenario memory _scenario
  ) public soldAll(_scenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector,
        mockCollateralType,
        address(auctionHouse),
        forgoneCollateralReceiver,
        _scenario.amountToSell - _scenario.boughtCollateral
      )
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_NotCall_SafeEngine_TransferCollateral_SendRemainingCollateralToForgoneReceiver_NotSoldAll(
    BuyCollateralScenario memory _scenario
  ) public notSoldAll(_scenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferCollateral.selector,
        mockCollateralType,
        address(auctionHouse),
        forgoneCollateralReceiver,
        _scenario.amountToSell - _scenario.boughtCollateral
      ),
      0
    );

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Set_LastReadRedemptionPrice(BuyCollateralScenario memory _scenario) public happyPath(_scenario) {
    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);

    assertEq(auctionHouse.lastReadRedemptionPrice(), _scenario.oracleRedemptionPrice);
  }

  function test_Set_Bid_AmountToSell_NotSoldAll(BuyCollateralScenario memory _scenario) public notSoldAll(_scenario) {
    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);

    assertEq(auctionHouse.auctions(_scenario.id).amountToSell, _scenario.amountToSell - _scenario.boughtCollateral);
  }

  function test_Set_Bid_AmountToRaise_NotSoldAll(BuyCollateralScenario memory _scenario) public notSoldAll(_scenario) {
    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);

    assertEq(auctionHouse.auctions(_scenario.id).amountToRaise, _scenario.amountToRaise - _scenario.wad * RAY);
  }

  function test_Delete_Bid(BuyCollateralScenario memory _scenario) public soldAll(_scenario) {
    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);

    bytes memory _result = abi.encode(auctionHouse.auctions(_scenario.id));
    IIncreasingDiscountCollateralAuctionHouse.Auction memory _emptyAuction;
    bytes memory _emptyAuctionBytes = abi.encode(_emptyAuction);

    assertEq(_result, _emptyAuctionBytes);
  }

  event BuyCollateral(uint256 indexed _id, uint256 _wad, uint256 _boughtCollateral);

  function test_Emit_BuyCollateral(BuyCollateralScenario memory _scenario) public soldAll(_scenario) {
    uint256 _adjustedBid = _scenario.amountToRaise / RAY + 1;
    vm.expectEmit(true, false, false, true);
    emit BuyCollateral(_scenario.id, _adjustedBid, _scenario.boughtCollateral);

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Emit_BuyCollateral_NotSoldAll(BuyCollateralScenario memory _scenario) public notSoldAll(_scenario) {
    vm.expectEmit(true, false, false, true);
    emit BuyCollateral(_scenario.id, _scenario.wad, _scenario.boughtCollateral);

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  event SettleAuction(uint256 indexed _id, uint256 _leftoverCollateral);

  function test_Emit_SettleAuction(BuyCollateralScenario memory _scenario) public soldAll(_scenario) {
    vm.expectEmit(true, false, false, true);
    emit SettleAuction(_scenario.id, 0);

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function testFail_Emit_SettleAuction_NotSoldAll(BuyCollateralScenario memory _scenario) public notSoldAll(_scenario) {
    vm.expectEmit(true, false, false, true);
    emit SettleAuction(_scenario.id, 0);

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Revert_InexistentAuction(BuyCollateralScenario memory _scenario) public {
    vm.assume(_scenario.id > 0);
    vm.assume(!_existentAuction(_scenario));

    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/inexistent-auction'));

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Revert_InvalidBid(BuyCollateralScenario memory _scenario) public {
    vm.assume(_scenario.id > 0);
    vm.assume(_existentAuction(_scenario));
    vm.assume(!_validBid(_scenario));

    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/invalid-bid'));

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Revert_FsmInvalidValue(BuyCollateralScenario memory _scenario) public {
    vm.assume(_scenario.id > 0);
    vm.assume(_existentAuction(_scenario));
    vm.assume(_validBid(_scenario));
    vm.assume(notOverflowMul(_scenario.wad, RAY));
    vm.assume(!_collateralFsmValidValue(_scenario));
    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/collateral-fsm-invalid-value'));

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Revert_NullBoughtAmount(BuyCollateralScenario memory _scenario) public {
    vm.assume(_scenario.id > 0);
    vm.assume(_existentAuction(_scenario));
    vm.assume(_validBid(_scenario));
    vm.assume(_collateralFsmValidValue(_scenario));
    vm.assume(notOverflowMul(_scenario.wad, RAY));

    _scenario.boughtCollateral = 0;
    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/null-bought-amount'));

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }

  function test_Revert_InvalidLeftToRaise(BuyCollateralScenario memory _scenario, uint256 _remainingToRaise) public {
    _happyPath(_scenario);
    vm.assume(_remainingToRaise > 0 && _remainingToRaise < RAY);
    _scenario.amountToRaise = _scenario.wad * RAY + _remainingToRaise;
    _mockValues(_scenario);

    vm.expectRevert(bytes('IncreasingDiscountCollateralAuctionHouse/invalid-left-to-raise'));

    auctionHouse.buyCollateral(_scenario.id, _scenario.wad);
  }
}
