// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common} from '@script/Common.s.sol';
import {
  IBaseOracle,
  IAccountingEngine,
  ICollateralAuctionHouse,
  IDebtAuctionHouse,
  ISurplusAuctionHouse,
  IOracleRelayer,
  ISAFEEngine,
  ILiquidationEngine,
  IStabilityFeeTreasury,
  IPIDController,
  IPIDRateSetter,
  ITaxCollector,
  IGlobalSettlement,
  IPostSettlementSurplusAuctionHouse
} from '@script/Contracts.s.sol';
import 'forge-std/console2.sol';

abstract contract VerifyParams is Common {
  function _verifyParams() internal view {
    ISAFEEngine.SAFEEngineParams memory SEParams = safeEngine.params();

    if (SEParams.safeDebtCeiling != _safeEngineParams.safeDebtCeiling) {
      console2.log('SAFEEngineParams: incorrect safeDebtCeiling: ', SEParams.safeDebtCeiling);
      console2.log('SAFEEngineParams: desired safeDebtCeiling: ', _safeEngineParams.safeDebtCeiling);
    }
    if (SEParams.globalDebtCeiling != _safeEngineParams.globalDebtCeiling) {
      console2.log('SAFEEngineParams: incorrect globalDebtCeiling: ', SEParams.globalDebtCeiling);
      console2.log('SAFEEngineParams: desired globalDebtCeiling: ', _safeEngineParams.globalDebtCeiling);
    }

    IAccountingEngine.AccountingEngineParams memory AEParams = accountingEngine.params();

    if (AEParams.surplusTransferPercentage != _accountingEngineParams.surplusTransferPercentage) {
      console2.log('AccountingEngineParams: incorrect surplusTransferPercentage: ', AEParams.surplusTransferPercentage);
      console2.log(
        'AccountingEngineParams: desired surplusTransferPercentage: ', _accountingEngineParams.surplusTransferPercentage
      );
    }
    if (AEParams.surplusDelay != _accountingEngineParams.surplusDelay) {
      console2.log('AccountingEngineParams: incorrect surplusDelay: ', AEParams.surplusDelay);
      console2.log('AccountingEngineParams: desired surplusDelay: ', _accountingEngineParams.surplusDelay);
    }
    if (AEParams.popDebtDelay != _accountingEngineParams.popDebtDelay) {
      console2.log('AccountingEngineParams: incorrect popDebtDelay: ', AEParams.popDebtDelay);
      console2.log('AccountingEngineParams: desired popDebtDelay: ', _accountingEngineParams.popDebtDelay);
    }
    if (AEParams.disableCooldown != _accountingEngineParams.disableCooldown) {
      console2.log('AccountingEngineParams: incorrect disableCooldown: ', AEParams.disableCooldown);
      console2.log('AccountingEngineParams: desired disableCooldown: ', _accountingEngineParams.disableCooldown);
    }
    if (AEParams.surplusAmount != _accountingEngineParams.surplusAmount) {
      console2.log('AccountingEngineParams: incorrect surplusAmount: ', AEParams.surplusAmount);
      console2.log('AccountingEngineParams: desired surplusAmount: ', _accountingEngineParams.surplusAmount);
    }
    if (AEParams.surplusBuffer != _accountingEngineParams.surplusBuffer) {
      console2.log('AccountingEngineParams: incorrect surplusBuffer: ', AEParams.surplusBuffer);
      console2.log('AccountingEngineParams: desired surplusBuffer: ', _accountingEngineParams.surplusBuffer);
    }
    if (AEParams.debtAuctionMintedTokens != _accountingEngineParams.debtAuctionMintedTokens) {
      console2.log('AccountingEngineParams: incorrect debtAuctionMintedTokens: ', AEParams.debtAuctionMintedTokens);
      console2.log(
        'AccountingEngineParams: desired debtAuctionMintedTokens: ', _accountingEngineParams.debtAuctionMintedTokens
      );
    }
    if (AEParams.debtAuctionBidSize != _accountingEngineParams.debtAuctionBidSize) {
      console2.log('AccountingEngineParams: incorrect debtAuctionBidSize: ', AEParams.debtAuctionBidSize);
      console2.log('AccountingEngineParams: desired debtAuctionBidSize: ', _accountingEngineParams.debtAuctionBidSize);
    }

    IDebtAuctionHouse.DebtAuctionHouseParams memory DAHParams = debtAuctionHouse.params();
    if (DAHParams.bidDecrease != _debtAuctionHouseParams.bidDecrease) {
      console2.log('DebtAuctionHouseParams: incorrect bidDecrease: ', DAHParams.bidDecrease);
      console2.log('DebtAuctionHouseParams: desired bidDecrease: ', _debtAuctionHouseParams.bidDecrease);
    }
    if (DAHParams.amountSoldIncrease != _debtAuctionHouseParams.amountSoldIncrease) {
      console2.log('DebtAuctionHouseParams: incorrect amountSoldIncrease: ', DAHParams.amountSoldIncrease);
      console2.log('DebtAuctionHouseParams: desired amountSoldIncrease: ', _debtAuctionHouseParams.amountSoldIncrease);
    }
    if (DAHParams.bidDuration != _debtAuctionHouseParams.bidDuration) {
      console2.log('DebtAuctionHouseParams: incorrect bidDuration: ', DAHParams.bidDuration);
      console2.log('DebtAuctionHouseParams: desired bidDuration: ', _debtAuctionHouseParams.bidDuration);
    }
    if (DAHParams.totalAuctionLength != _debtAuctionHouseParams.totalAuctionLength) {
      console2.log('DebtAuctionHouseParams: incorrect totalAuctionLength: ', DAHParams.totalAuctionLength);
      console2.log('DebtAuctionHouseParams: desired totalAuctionLength: ', _debtAuctionHouseParams.totalAuctionLength);
    }

    ISurplusAuctionHouse.SurplusAuctionHouseParams memory SAHParams = surplusAuctionHouse.params();

    if (SAHParams.bidIncrease != _surplusAuctionHouseParams.bidIncrease) {
      console2.log('SurplusAuctionHouseParams: incorrect bidIncrease: ', SAHParams.bidIncrease);
      console2.log('SurplusAuctionHouseParams: desired bidIncrease: ', _surplusAuctionHouseParams.bidIncrease);
    }
    if (SAHParams.bidDuration != _surplusAuctionHouseParams.bidDuration) {
      console2.log('SurplusAuctionHouseParams: incorrect bidDuration: ', SAHParams.bidDuration);
      console2.log('SurplusAuctionHouseParams: desired bidDuration: ', _surplusAuctionHouseParams.bidDuration);
    }
    if (address(SAHParams.bidReceiver) != address(_surplusAuctionHouseParams.bidReceiver)) {
      console2.log('SurplusAuctionHouseParams: incorrect bidReceiver: ', address(SAHParams.bidReceiver));
      console2.log('SurplusAuctionHouseParams: desired bidReceiver: ', address(_surplusAuctionHouseParams.bidReceiver));
    }
    if (SAHParams.totalAuctionLength != _surplusAuctionHouseParams.totalAuctionLength) {
      console2.log('SurplusAuctionHouseParams: incorrect totalAuctionLength: ', SAHParams.totalAuctionLength);
      console2.log(
        'SurplusAuctionHouseParams: desired totalAuctionLength: ', _surplusAuctionHouseParams.totalAuctionLength
      );
    }
    if (SAHParams.recyclingPercentage != _surplusAuctionHouseParams.recyclingPercentage) {
      console2.log('SurplusAuctionHouseParams: incorrect recyclingPercentage: ', SAHParams.recyclingPercentage);
      console2.log(
        'SurplusAuctionHouseParams: desired recyclingPercentage: ', _surplusAuctionHouseParams.recyclingPercentage
      );
    }

    //TODO for some reason fetching these params causes a revert with no info...

    // ILiquidationEngine.LiquidationEngineParams memory LEParams = liquidationEngine.params();

    // if (LEParams.onAuctionSystemCoinLimit != _liquidationEngineParams.onAuctionSystemCoinLimit) {
    //   console2.log('LiquidationEngineParams: incorrect onAuctionSystemCoinLimit: ', LEParams.onAuctionSystemCoinLimit);
    //   console2.log(
    //     'LiquidationEngineParams: desired onAuctionSystemCoinLimit: ', _liquidationEngineParams.onAuctionSystemCoinLimit
    //   );
    // }
    // if (LEParams.saviourGasLimit != _liquidationEngineParams.saviourGasLimit) {
    //   console2.log('LiquidationEngineParams: incorrect saviourGasLimit: ', LEParams.saviourGasLimit);
    //   console2.log('LiquidationEngineParams: desired saviourGasLimit: ', _liquidationEngineParams.saviourGasLimit);
    // }

    //STABILITY FEE TREASURY
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory SFTParams = stabilityFeeTreasury.params();

    if (SFTParams.treasuryCapacity != _stabilityFeeTreasuryParams.treasuryCapacity) {
      console2.log('StabilityFeeTreasuryParams: incorrect treasuryCapacity: ', SFTParams.treasuryCapacity);
      console2.log(
        'StabilityFeeTreasuryParams: desired treasuryCapacity: ', _stabilityFeeTreasuryParams.treasuryCapacity
      );
    }
    if (SFTParams.pullFundsMinThreshold != _stabilityFeeTreasuryParams.pullFundsMinThreshold) {
      console2.log('StabilityFeeTreasuryParams: incorrect pullFundsMinThreshold: ', SFTParams.pullFundsMinThreshold);
      console2.log(
        'StabilityFeeTreasuryParams: desired pullFundsMinThreshold: ', _stabilityFeeTreasuryParams.pullFundsMinThreshold
      );
    }
    if (SFTParams.surplusTransferDelay != _stabilityFeeTreasuryParams.surplusTransferDelay) {
      console2.log('StabilityFeeTreasuryParams: incorrect surplusTransferDelay: ', SFTParams.surplusTransferDelay);
      console2.log(
        'StabilityFeeTreasuryParams: desired surplusTransferDelay: ', _stabilityFeeTreasuryParams.surplusTransferDelay
      );
    }
    // TAXCOLLECTOR
    ITaxCollector.TaxCollectorParams memory TCParams = taxCollector.params();

    if (TCParams.primaryTaxReceiver != _taxCollectorParams.primaryTaxReceiver) {
      console2.log('TaxCollectorParams: incorrect primaryTaxReceiver: ', TCParams.primaryTaxReceiver);
      console2.log('TaxCollectorParams: desired primaryTaxReceiver: ', _taxCollectorParams.primaryTaxReceiver);
    }
    if (TCParams.globalStabilityFee != _taxCollectorParams.globalStabilityFee) {
      console2.log('TaxCollectorParams: incorrect globalStabilityFee: ', TCParams.globalStabilityFee);
      console2.log('TaxCollectorParams: desired globalStabilityFee: ', _taxCollectorParams.globalStabilityFee);
    }
    if (TCParams.maxStabilityFeeRange != _taxCollectorParams.maxStabilityFeeRange) {
      console2.log('TaxCollectorParams: incorrect maxStabilityFeeRange: ', TCParams.maxStabilityFeeRange);
      console2.log('TaxCollectorParams: desired maxStabilityFeeRange: ', _taxCollectorParams.maxStabilityFeeRange);
    }
    if (TCParams.maxSecondaryReceivers != _taxCollectorParams.maxSecondaryReceivers) {
      console2.log('TaxCollectorParams: incorrect maxSecondaryReceivers: ', TCParams.maxSecondaryReceivers);
      console2.log('TaxCollectorParams: desired maxSecondaryReceivers: ', _taxCollectorParams.maxSecondaryReceivers);
    }
    // ORACLE RELAYER
    IOracleRelayer.OracleRelayerParams memory ORParams = oracleRelayer.params();

    if (ORParams.redemptionRateUpperBound != _oracleRelayerParams.redemptionRateUpperBound) {
      console2.log('OracleRelayerParams: incorrect redemptionRateUpperBound: ', ORParams.redemptionRateUpperBound);
      console2.log(
        'OracleRelayerParams: desired redemptionRateUpperBound: ', _oracleRelayerParams.redemptionRateUpperBound
      );
    }
    if (ORParams.redemptionRateLowerBound != _oracleRelayerParams.redemptionRateLowerBound) {
      console2.log('OracleRelayerParams: incorrect redemptionRateLowerBound: ', ORParams.redemptionRateLowerBound);
      console2.log(
        'OracleRelayerParams: desired redemptionRateLowerBound: ', _oracleRelayerParams.redemptionRateLowerBound
      );
    }
    // PID CONTROLLER
    IPIDController.PIDControllerParams memory PIDCParams = pidController.params();

    if (PIDCParams.perSecondCumulativeLeak != _pidControllerParams.perSecondCumulativeLeak) {
      console2.log('PIDControllerParams: incorrect perSecondCumulativeLeak: ', PIDCParams.perSecondCumulativeLeak);
      console2.log(
        'PIDControllerParams: desired perSecondCumulativeLeak: ', _pidControllerParams.perSecondCumulativeLeak
      );
    }
    if (PIDCParams.noiseBarrier != _pidControllerParams.noiseBarrier) {
      console2.log('PIDControllerParams: incorrect noiseBarrier: ', PIDCParams.noiseBarrier);
      console2.log('PIDControllerParams: desired noiseBarrier: ', _pidControllerParams.noiseBarrier);
    }
    if (PIDCParams.feedbackOutputLowerBound != _pidControllerParams.feedbackOutputLowerBound) {
      console2.log('PIDControllerParams: incorrect feedbackOutputLowerBound: ');
      console2.logInt(PIDCParams.feedbackOutputLowerBound);
      console2.log('PIDControllerParams: desired feedbackOutputLowerBound: ');
      console2.logInt(_pidControllerParams.feedbackOutputLowerBound);
    }
    if (PIDCParams.feedbackOutputUpperBound != _pidControllerParams.feedbackOutputUpperBound) {
      console2.log('PIDControllerParams: incorrect feedbackOutputUpperBound: ', PIDCParams.feedbackOutputUpperBound);
      console2.log(
        'PIDControllerParams: desired feedbackOutputUpperBound: ', _pidControllerParams.feedbackOutputUpperBound
      );
    }
    if (PIDCParams.integralPeriodSize != _pidControllerParams.integralPeriodSize) {
      console2.log('PIDControllerParams: incorrect integralPeriodSize: ', PIDCParams.integralPeriodSize);
      console2.log('PIDControllerParams: desired integralPeriodSize: ', _pidControllerParams.integralPeriodSize);
    }

    // CONTROLLER GAINS

    IPIDController.ControllerGains memory PIDCGParams = pidController.controllerGains();

    if (PIDCGParams.ki != _pidControllerGains.ki) {
      console2.log('ControllerGains: incorrect ki: ');
      console2.logInt(PIDCGParams.ki);
      console2.log('ControllerGains: desired ki: ');
      console2.logInt(_pidControllerGains.ki);
    }
    if (PIDCGParams.kp != _pidControllerGains.kp) {
      console2.log('ControllerGains: incorrect kp: ');
      console2.logInt(PIDCGParams.kp);
      console2.log('ControllerGains: desired kp: ');
      console2.logInt(_pidControllerGains.kp);
    }

    IPIDRateSetter.PIDRateSetterParams memory PIDRSParams = pidRateSetter.params();

    if (PIDRSParams.updateRateDelay != _pidRateSetterParams.updateRateDelay) {
      console2.log('PIDRateSetterParams: incorrect updateRateDelay: ', PIDRSParams.updateRateDelay);
      console2.log('PIDRateSetterParams: desired updateRateDelay: ', _pidRateSetterParams.updateRateDelay);
    }

    IGlobalSettlement.GlobalSettlementParams memory GSParams = globalSettlement.params();

    if (GSParams.shutdownCooldown != _globalSettlementParams.shutdownCooldown) {
      console2.log('GlobalSettlementParams: incorrect shutdownCooldown: ', GSParams.shutdownCooldown);
      console2.log('GlobalSettlementParams: desired shutdownCooldown: ', _globalSettlementParams.shutdownCooldown);
    }

    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory PSSAHParams =
      postSettlementSurplusAuctionHouse.params();

    if (PSSAHParams.bidIncrease != _postSettlementSAHParams.bidIncrease) {
      console2.log('PostSettlementSAHParams: incorrect bidIncrease: ', PSSAHParams.bidIncrease);
      console2.log('PostSettlementSAHParams: desired bidIncrease: ', _postSettlementSAHParams.bidIncrease);
    }
    if (PSSAHParams.bidDuration != _postSettlementSAHParams.bidDuration) {
      console2.log('PostSettlementSAHParams: incorrect bidDuration: ', PSSAHParams.bidDuration);
      console2.log('PostSettlementSAHParams: desired bidDuration: ', _postSettlementSAHParams.bidDuration);
    }
    if (PSSAHParams.totalAuctionLength != _postSettlementSAHParams.totalAuctionLength) {
      console2.log('PostSettlementSAHParams: incorrect totalAuctionLength: ', PSSAHParams.totalAuctionLength);
      console2.log('PostSettlementSAHParams: desired totalAuctionLength: ', _postSettlementSAHParams.totalAuctionLength);
    }
  }

  function _verifyCollateralParams() internal view {
    bytes32[] memory collateralList = collateralAuctionHouseFactory.collateralList(); // bytes32 collateralTypes for collat auction

    // verify params for every collateral type in collateral Auction house.
    for (uint256 i; i < collateralList.length; i++) {
      bytes32 _cType = collateralList[i];

      ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams =
        collateralAuctionHouseFactory.cParams(_cType);

      if (_cahCParams.minimumBid != _collateralAuctionHouseParams[_cType].minimumBid) {
        console2.log('incorrect minimumBid: ', _cahCParams.minimumBid);
        console2.log('desired minimumBid: ', _collateralAuctionHouseParams[_cType].minimumBid);
      }
      if (_cahCParams.minDiscount != _collateralAuctionHouseParams[_cType].minDiscount) {
        console2.log('incorrect minimumDiscount: ', _cahCParams.minDiscount);
        console2.log('desired minimumDiscount: ', _collateralAuctionHouseParams[_cType].minDiscount);
      }
      if (_cahCParams.maxDiscount != _collateralAuctionHouseParams[_cType].maxDiscount) {
        console2.log('incorrect max discount: ', _cahCParams.maxDiscount);
        console2.log('desired max discount: ', _collateralAuctionHouseParams[_cType].maxDiscount);
      }
      if (_cahCParams.perSecondDiscountUpdateRate != _collateralAuctionHouseParams[_cType].perSecondDiscountUpdateRate)
      {
        console2.log('incorrect perSecondDiscountUpdateRate: ', _cahCParams.perSecondDiscountUpdateRate);
        console2.log(
          'desired perSecondDiscountUpdateRate: ', _collateralAuctionHouseParams[_cType].perSecondDiscountUpdateRate
        );
      }

      IOracleRelayer.OracleRelayerCollateralParams memory _ORParams = oracleRelayer.cParams(_cType);

      if (address(_ORParams.oracle) != address(_oracleRelayerCParams[_cType].oracle)) {
        console2.log('incorrect Oracle :', address(_ORParams.oracle));
        console2.log('desired Oracle: ', address(_oracleRelayerCParams[_cType].oracle));
      }
      if (_ORParams.safetyCRatio != _oracleRelayerCParams[_cType].safetyCRatio) {
        console2.log('incorrect safetyCRatio: ', _ORParams.safetyCRatio);
        console2.log('desired safetyCRatio: ', _oracleRelayerCParams[_cType].safetyCRatio);
      }
      if (_ORParams.liquidationCRatio != _oracleRelayerCParams[_cType].liquidationCRatio) {
        console2.log('incorrect liquidationCRatio: ', _ORParams.liquidationCRatio);
        console2.log('desired liquidationCRatio: ', _oracleRelayerCParams[_cType].liquidationCRatio);
      }

      ITaxCollector.TaxCollectorCollateralParams memory _TCParams = taxCollector.cParams(_cType);
      if (_TCParams.stabilityFee != _taxCollectorCParams[_cType].stabilityFee) {
        console2.log('incorrect stabilityFee: ', _TCParams.stabilityFee);
        console2.log('desired stabilityFee: ', _taxCollectorCParams[_cType].stabilityFee);
      }

      ISAFEEngine.SAFEEngineCollateralParams memory _SAFEECParams = safeEngine.cParams(_cType);
      if (_SAFEECParams.debtCeiling != _safeEngineCParams[_cType].debtCeiling) {
        console2.log('incorrect debtCeiling: ', _SAFEECParams.debtCeiling);
        console2.log('desired debtCeiling: ', _safeEngineCParams[_cType].debtCeiling);
      }
      if (_SAFEECParams.debtFloor != _safeEngineCParams[_cType].debtFloor) {
        console2.log('incorrect debtFloor: ', _SAFEECParams.debtFloor);
        console2.log('desired debtFloor: ', _safeEngineCParams[_cType].debtFloor);
      }

      ILiquidationEngine.LiquidationEngineCollateralParams memory _LECParams = liquidationEngine.cParams(_cType);

      if (_LECParams.collateralAuctionHouse != _liquidationEngineCParams[_cType].collateralAuctionHouse) {
        console2.log('incorrect collateralAuctionHouse: ', _LECParams.collateralAuctionHouse);
        console2.log('desired collateralAuctionHouse: ', _liquidationEngineCParams[_cType].collateralAuctionHouse);
      }
      if (_LECParams.liquidationPenalty != _liquidationEngineCParams[_cType].liquidationPenalty) {
        console2.log('incorrect liquidationPenalty: ', _LECParams.liquidationPenalty);
        console2.log('desired liquidationPenalty: ', _liquidationEngineCParams[_cType].liquidationPenalty);
      }
      if (_LECParams.liquidationQuantity != _liquidationEngineCParams[_cType].liquidationQuantity) {
        console2.log('incorrect liquidationQuantity: ', _LECParams.liquidationQuantity);
        console2.log('desired liquidationQuantity: ', _liquidationEngineCParams[_cType].liquidationQuantity);
      }
      console2.log('Collateral type ', i, ' verified.');
    }
  }
}
