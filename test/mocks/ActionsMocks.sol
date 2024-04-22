// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';

contract CollateralJoinMock {
  bool public wasJoinCalled;
  bool public wasExitCalled;
  address public collateralToken;
  address public safeEngine;

  function reset() external {
    wasJoinCalled = false;
    wasExitCalled = false;
    collateralToken = address(0);
    safeEngine = address(0);
  }

  function _mock_setCollateralToken(address _collateralToken) external {
    collateralToken = _collateralToken;
  }

  function _mock_setSafeEngine(address _safeEngine) external {
    safeEngine = _safeEngine;
  }

  function collateral() external view returns (IERC20Metadata _collateral) {
    return IERC20Metadata(collateralToken);
  }

  function join(address _account, uint256 _wei) external {
    wasJoinCalled = true;
  }

  function systemCoin() external view returns (address) {
    return collateralToken;
  }

  function decimals() external view returns (uint256) {
    return 18;
  }

  function exit(address _account, uint256 _wei) external {
    wasExitCalled = true;
  }

  function collateralType() external view returns (bytes32) {
    return bytes32(0);
  }
}

contract CoinJoinMock {
  address public safeEngine;
  ISystemCoin public systemCoin;

  bool public wasExitCalled;
  bool public wasJoinCalled;

  constructor() {
    safeEngine = address(new SafeEngineMock());
    systemCoin = ISystemCoin(address(new ProtocolToken()));
    systemCoin.initialize('SystemCoin', 'SysCoin');
    systemCoin.mint(address(this), 1000 ether);
    systemCoin.mint(address(0x1), 1000 ether);
  }

  function reset() external {
    wasExitCalled = false;
    wasJoinCalled = false;
    SafeEngineMock(safeEngine).reset();
  }

  function _mock_systemCoinMint(address _account, uint256 _wad) public {
    systemCoin.mint(_account, _wad);
  }

  function exit(address _account, uint256 _wad) external {
    wasExitCalled = true;
  }

  function join(address _account, uint256 _wad) external {
    wasJoinCalled = true;
  }

  function decimals() external view returns (uint256) {
    return 18;
  }
}

contract ODSafeManagerMock {
  IODSafeManager.SAFEData public safeDataPoint;
  ISAFEEngine.SAFEEngineCollateralData public collateralDataPoint;
  address public safeEngine;

  bool public wasQuitSystemCalled;
  bool public wasOpenSAFECalled;
  bool public wasEnterSystemCalled;
  bool public wasAllowSAFECalled;
  bool public wasMoveSAFECalled;
  bool public wasAddSAFECalled;
  bool public wasRemoveSAFECalled;
  bool public wasProtectSAFECalled;
  bool public wasModifySAFECollateralizationCalled;
  bool public wasTransferCollateralCalled;
  bool public wasTaxCollectorTaxSingleCalled;
  bool public wasTransferInteralCoinsCalled;
  uint256 public collateralBalance;
  uint256 public safeId;

  constructor() {
    safeEngine = address(new SafeEngineMock());
  }

  function reset() external {
    safeDataPoint = IODSafeManager.SAFEData(0, address(0), address(0), bytes32(0));
    safeId = 0;
    wasQuitSystemCalled = false;
    wasOpenSAFECalled = false;
    wasAllowSAFECalled = false;
    wasEnterSystemCalled = false;
    wasMoveSAFECalled = false;
    wasAddSAFECalled = false;
    wasRemoveSAFECalled = false;
    wasProtectSAFECalled = false;
    wasModifySAFECollateralizationCalled = false;
    wasTransferCollateralCalled = false;
    wasTransferInteralCoinsCalled = false;
    wasTaxCollectorTaxSingleCalled = false;
    collateralBalance = 0;
  }

  function _mock_setSafeData(uint96 _nonce, address _owner, address _safeHandler, bytes32 _collateralType) external {
    safeDataPoint = IODSafeManager.SAFEData(_nonce, _owner, _safeHandler, _collateralType);
  }

  function _mock_setCollateralBalance(uint256 _collateralBalance) external {
    collateralBalance = _collateralBalance;
  }

  function _mock_setSafeId(uint256 _safeId) external {
    safeId = _safeId;
  }

  function safeData(uint256 _safe) external view returns (IODSafeManager.SAFEData memory _sData) {
    return safeDataPoint;
  }

  function quitSystem(uint256 _safe) external {
    wasQuitSystemCalled = true;
  }

  function enterSystem(address _src, uint256 _safe) external {
    wasEnterSystemCalled = true;
  }

  function tokenCollateral(bytes32 _cType, address _account) external view returns (uint256 _collateralBalance) {
    return collateralBalance;
  }

  function openSAFE(bytes32 _cType, address _usr) external returns (uint256 _id) {
    wasOpenSAFECalled = true;
    return safeId;
  }

  function allowSAFE(uint256 _safe, address _usr, bool _ok) external {
    wasAllowSAFECalled = true;
  }

  function moveSAFE(uint256 _safeSrc, uint256 _safeDst) external {
    wasMoveSAFECalled = true;
  }

  function addSAFE(uint256 _safe) external {
    wasAddSAFECalled = true;
  }

  function removeSAFE(uint256 _safe) external {
    wasRemoveSAFECalled = true;
  }

  function protectSAFE(uint256 _safe, address _handler) external {
    wasProtectSAFECalled = true;
  }

  function modifySAFECollateralization(
    uint256 _safe,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    bool _nonSafeHandlerAddress
  ) external {
    wasModifySAFECollateralizationCalled = true;
  }

  function transferCollateral(uint256 _safe, address _dst, uint256 _wad) external {
    wasTransferCollateralCalled = true;
  }

  function transferInternalCoins(uint256 _safe, address _dst, uint256 _rad) external {
    wasTransferInteralCoinsCalled = true;
  }

  function taxCollector() external view returns (address) {
    return address(this);
  }

  function taxSingle(bytes32 _cType) external returns (uint256 _latestAccumulatedRate) {
    wasTaxCollectorTaxSingleCalled = true;
    return 0;
  }
}

contract GlobalSettlementMock {
  bool public wasProcessSAFECalled;
  bool public wasFreeCollateralCalled;
  bool public wasPrepareCoinsForRedeemingCalled;
  bool public wasRedeemCollateralCalled;

  uint256 public coinBagPoint;
  uint256 public coinsUsedToRedeemPoint;

  address public safeEngine;

  function reset() external {
    wasProcessSAFECalled = false;
    wasFreeCollateralCalled = false;
    wasPrepareCoinsForRedeemingCalled = false;
    wasRedeemCollateralCalled = false;
    coinBagPoint = 0;
    coinsUsedToRedeemPoint = 0;
  }

  function _mock_setSafeEngine(address _safeEngine) external {
    safeEngine = _safeEngine;
  }

  function _mock_setCoinBag(uint256 _coinBag) external {
    coinBagPoint = _coinBag;
  }

  function _mock_setCoinsUsedToRedeem(uint256 _coinsUsedToRedeem) external {
    coinsUsedToRedeemPoint = _coinsUsedToRedeem;
  }

  function processSAFE(bytes32 _cType, address _safe) external {
    wasProcessSAFECalled = true;
  }

  function freeCollateral(bytes32 _cType) external {
    wasFreeCollateralCalled = true;
  }

  function prepareCoinsForRedeeming(uint256 _coinAmount) external {
    wasPrepareCoinsForRedeemingCalled = true;
  }

  function coinBag(address _coinHolder) external view returns (uint256 _coinBag) {
    return coinBagPoint;
  }

  function coinsUsedToRedeem(bytes32 _cType, address _coinHolder) external view returns (uint256 _coinsUsedToRedeem) {
    return coinsUsedToRedeemPoint;
  }

  function redeemCollateral(bytes32 _cType, uint256 _coinsAmount) external {
    wasRedeemCollateralCalled = true;
  }
}

contract SafeEngineMock {
  bool public wasApproveSAFEModificationCalled;

  bool public canModifySAF;
  ISAFEEngine.SAFE public safe;
  uint256 public collateralBalance;
  uint256 public coinBalancePoint;
  ISAFEEngine.SAFEEngineCollateralData collateralDataPoint;

  function reset() external {
    collateralDataPoint = ISAFEEngine.SAFEEngineCollateralData(0, 0, 0, 0, 0);
    wasApproveSAFEModificationCalled = false;
    canModifySAF = false;
    safe = ISAFEEngine.SAFE(0, 0);
    collateralBalance = 0;
  }

  function _mock_setCollateralBalance(uint256 _collateralBalance) external {
    collateralBalance = _collateralBalance;
  }

  function _mock_setCollateralData(
    uint256 _debtAmount,
    uint256 _lockedAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _liquidationPrice
  ) external {
    collateralDataPoint = ISAFEEngine.SAFEEngineCollateralData(
      _debtAmount, _lockedAmount, _accumulatedRate, _safetyPrice, _liquidationPrice
    );
  }

  function _mock_addSafeData(uint256 lockedCollateral, uint256 generatedDebt) external {
    safe = ISAFEEngine.SAFE(lockedCollateral, generatedDebt);
  }

  function _mock_setCanModifySAFE(bool _canModifySAFE) external {
    canModifySAF = _canModifySAFE;
  }

  function _mock_setCoinBalance(uint256 _coinBalance) external {
    coinBalancePoint = _coinBalance;
  }

  function canModifySAFE(address _safe, address _account) external view returns (bool _allowed) {
    return canModifySAF;
  }

  function approveSAFEModification(address _account) external {
    wasApproveSAFEModificationCalled = true;
  }

  function tokenCollateral(bytes32 _cType, address _account) external view returns (uint256 _collateralBalance) {
    return collateralBalance;
  }

  function safes(bytes32 _cType, address _safeAddress) external view returns (ISAFEEngine.SAFE memory _safeData) {
    return safe;
  }

  function coinBalance(address _account) external view returns (uint256 _coinBalance) {
    return coinBalancePoint;
  }

  function cData(bytes32 _cType) external view returns (ISAFEEngine.SAFEEngineCollateralData memory _safeEngineCData) {
    return collateralDataPoint;
  }
}

contract SurplusActionsHouseMock {
  address public highBidder;
  ProtocolToken public protocolTokenContract;
  address public protocolToken;

  bool public wasSettleAuctionCalled;
  bool public wasIncreaseBidSizeCalled;

  constructor() {
    protocolTokenContract = new ProtocolToken();
    protocolTokenContract.initialize('Protocol Token', 'PT');
    protocolTokenContract.mint(address(this), 1000 ether);
    protocolTokenContract.mint(address(0x1), 1000 ether);
    protocolToken = address(protocolTokenContract);
  }

  function reset() external {
    highBidder = address(0);
    wasIncreaseBidSizeCalled = false;
    wasSettleAuctionCalled = false;
  }

  function setHighBidder(address _highBidder) external {
    highBidder = _highBidder;
  }

  function auctions(uint256 _id) external view returns (ICommonSurplusAuctionHouse.Auction memory _auction) {
    return ICommonSurplusAuctionHouse.Auction({
      bidAmount: 100,
      amountToSell: 100,
      highBidder: highBidder == address(0) ? address(0x1) : highBidder,
      bidExpiry: 100,
      auctionDeadline: 100
    });
  }

  function increaseBidSize(uint256 _auctionId, uint256 _bidAmount) external {
    wasIncreaseBidSizeCalled = true;
  }

  function settleAuction(uint256 _auctionId) external {
    wasSettleAuctionCalled = true;
  }
}

contract CollateralAuctionHouseMock {
  bool public wasBuyCollateralCalled;

  function reset() external {
    wasBuyCollateralCalled = false;
  }

  function buyCollateral(uint256 _auctionId, uint256 _bidAmount) external returns (uint256, uint256) {
    wasBuyCollateralCalled = true;
    return (1, 1);
  }
}

contract DebtAuctionHouseMock {
  bool public wasDecreaseSoldAmountCalled;
  bool public wasSettleAuctionCalled;
  IDebtAuctionHouse.Auction public auction;

  function reset() external {
    wasDecreaseSoldAmountCalled = false;
    wasSettleAuctionCalled = false;
  }

  function auctions(uint256 _id) external view returns (IDebtAuctionHouse.Auction memory _auction) {
    return auction;
  }

  function _mock_setAuction(
    uint256 bidAmount,
    uint256 amountToSell,
    address highBidder,
    uint256 bidExpiry,
    uint256 auctionDeadline
  ) external {
    auction = IDebtAuctionHouse.Auction(bidAmount, amountToSell, highBidder, bidExpiry, auctionDeadline);
  }

  function decreaseSoldAmount(uint256 _id, uint256 _amountToBuy) external {
    wasDecreaseSoldAmountCalled = true;
  }

  function settleAuction(uint256 _id) external {
    wasSettleAuctionCalled = true;
  }
}

contract AccountingJobMock {
  bool public wasWorkAuctionDebtCalled;
  bool public wasWorkAuctionSurplusCalled;
  bool public wasWorkPopDebtFromQueueCalled;
  uint256 public rewardAmount;

  function reset() external {
    wasWorkAuctionDebtCalled = false;
    wasWorkAuctionSurplusCalled = false;
    wasWorkPopDebtFromQueueCalled = false;
  }

  function _mock_setRewardAmount(uint256 _rewardAmount) external {
    rewardAmount = _rewardAmount;
  }

  function workAuctionDebt() external {
    wasWorkAuctionDebtCalled = true;
  }

  function workAuctionSurplus() external {
    wasWorkAuctionSurplusCalled = true;
  }

  function workPopDebtFromQueue(uint256 _debtBlockTimestamp) external {
    wasWorkPopDebtFromQueueCalled = true;
  }
}

contract LiquidationEngineMock {
  bool public wasWorkLiquidationCalled;
  uint256 public rewardAmount;

  function reset() external {
    wasWorkLiquidationCalled = false;
  }

  function _mock_setRewardAmount(uint256 _rewardAmount) external {
    rewardAmount = _rewardAmount;
  }

  function workLiquidation(bytes32 _cType, address _safe) external {
    wasWorkLiquidationCalled = true;
  }
}

contract OracleJobMock {
  bool public wasWorkUpdateCollateralPrice;
  bool public wasWorkUpdateRate;
  uint256 public rewardAmount;

  function _mock_setRewardAmount(uint256 _rewardAmount) external {
    rewardAmount = _rewardAmount;
  }

  function reset() external {
    wasWorkUpdateCollateralPrice = false;
    wasWorkUpdateRate = false;
  }

  function workUpdateCollateralPrice(bytes32 _cType) external {
    wasWorkUpdateCollateralPrice = true;
  }

  function workUpdateRate() external {
    wasWorkUpdateCollateralPrice = true;
  }
}
