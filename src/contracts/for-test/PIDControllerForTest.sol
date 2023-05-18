// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IPIDController, PIDController} from '@contracts/PIDController.sol';
import {InternalCallsWatcher, InternalCallsExtension} from '@test/utils/InternalCallsWatcher.sol';

contract PIDControllerForTest is PIDController, InternalCallsExtension {
  MockPIDController public mockPIDController;

  constructor(
    int256 _Kp,
    int256 _Ki,
    uint256 _perSecondCumulativeLeak,
    uint256 _integralPeriodSize,
    uint256 _noiseBarrier,
    uint256 _feedbackOutputUpperBound,
    int256 _feedbackOutputLowerBound,
    int256[] memory _importedState,
    MockPIDController _mockPIDController
  )
    PIDController(
      _Kp,
      _Ki,
      _perSecondCumulativeLeak,
      _integralPeriodSize,
      _noiseBarrier,
      _feedbackOutputUpperBound,
      _feedbackOutputLowerBound,
      _importedState
    )
  {
    mockPIDController = _mockPIDController;
  }

  function _getBoundedPIOutput(int256 _piOutput) internal view virtual override returns (int256 _boundedPIOutput) {
    watcher.calledInternal(abi.encodeWithSignature('_getBoundedPIOutput(int256)', _piOutput));
    if (callSuper) {
      return super._getBoundedPIOutput(_piOutput);
    } else {
      return mockPIDController.mock_getBoundedPIOutput(_piOutput);
    }
  }

  function call_getBoundedPIOutput(int256 _piOutput) external view returns (int256 _boundedPIOutput) {
    return _getBoundedPIOutput(_piOutput);
  }

  function _getProportionalTerm(
    uint256 _marketPrice,
    uint256 _redemptionPrice
  ) internal view virtual override returns (int256 _proportionalTerm) {
    watcher.calledInternal(
      abi.encodeWithSignature('_getProportionalTerm(uint256,uint256)', _marketPrice, _redemptionPrice)
    );
    if (callSuper) {
      return super._getProportionalTerm(_marketPrice, _redemptionPrice);
    } else {
      return mockPIDController.mock_getProportionalTerm(_marketPrice, _redemptionPrice);
    }
  }

  bool callSupper_getNextPriceDeviationCumulative = true;

  function setCallSupper_getNextPriceDeviationCumulative(bool _callSuper) external {
    callSupper_getNextPriceDeviationCumulative = _callSuper;
  }

  function _getNextPriceDeviationCumulative(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  )
    internal
    view
    virtual
    override
    returns (int256 _leakedPlusNewTimeAdjustedDeviation, int256 _newTimeAdjustedDeviation)
  {
    watcher.calledInternal(
      abi.encodeWithSignature('_getNextPriceDeviationCumulative(int256,uint256)', _proportionalTerm, _accumulatedLeak)
    );
    if (callSuper || callSupper_getNextPriceDeviationCumulative) {
      return super._getNextPriceDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    } else {
      return mockPIDController.mock_getNextPriceDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    }
  }

  bool callSupper_getGainAdjustedPIOutput = true;

  function setCallSupper_getGainAdjustedPIOutput(bool _callSuper) external {
    callSupper_getGainAdjustedPIOutput = _callSuper;
  }

  function _getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) internal view virtual override returns (int256 _gainAdjustedPIOutput) {
    watcher.calledInternal(
      abi.encodeWithSignature('_getGainAdjustedPIOutput(int256,int256)', _proportionalTerm, _integralTerm)
    );
    if (callSuper || callSupper_getGainAdjustedPIOutput) {
      return super._getGainAdjustedPIOutput(_proportionalTerm, _integralTerm);
    } else {
      return mockPIDController.mock_getGainAdjustedPIOutput(_proportionalTerm, _integralTerm);
    }
  }

  function _breaksNoiseBarrier(
    uint256 _piSum,
    uint256 _redemptionPrice
  ) internal view virtual override returns (bool _breaks) {
    watcher.calledInternal(abi.encodeWithSignature('_breaksNoiseBarrier(uint256,uint256)', _piSum, _redemptionPrice));
    if (callSuper) {
      return super._breaksNoiseBarrier(_piSum, _redemptionPrice);
    } else {
      return mockPIDController.mock_breaksNoiseBarrier(_piSum, _redemptionPrice);
    }
  }

  function _getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) internal view virtual override returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {
    watcher.calledInternal(
      abi.encodeWithSignature('_getGainAdjustedTerms(int256,int256)', _proportionalTerm, _integralTerm)
    );
    if (callSuper) {
      return super._getGainAdjustedTerms(_proportionalTerm, _integralTerm);
    } else {
      return mockPIDController.mock_getGainAdjustedTerms(_proportionalTerm, _integralTerm);
    }
  }

  bool callSupper_getBoundedRedemptionRate = true;

  function setCallSupper_getBoundedRedemptionRate(bool _callSuper) external {
    callSupper_getBoundedRedemptionRate = _callSuper;
  }

  function _getBoundedRedemptionRate(int256 _piOutput) internal view virtual override returns (uint256, uint256) {
    watcher.calledInternal(abi.encodeWithSignature('_getBoundedRedemptionRate(int256)', _piOutput));
    if (callSuper || callSupper_getBoundedRedemptionRate) {
      return super._getBoundedRedemptionRate(_piOutput);
    } else {
      return mockPIDController.mock_getBoundedRedemptionRate(_piOutput);
    }
  }

  function _oll() internal view virtual override returns (uint256) {
    watcher.calledInternal(abi.encodeWithSignature('_oll()'));
    if (callSuper) {
      return super._oll();
    } else {
      return mockPIDController.mock_oll();
    }
  }

  function _getLastProportionalTerm() internal view virtual override returns (int256) {
    watcher.calledInternal(abi.encodeWithSignature('_getLastProportionalTerm()'));
    if (callSuper) {
      return super._getLastProportionalTerm();
    } else {
      return mockPIDController.mock_getLastProportionalTerm();
    }
  }

  bool callSupper_updateDeviationHistory = true;

  function setCallSupper_updateDeviationHistory(bool _callSuper) external {
    callSupper_updateDeviationHistory = _callSuper;
  }

  function _updateDeviationHistory(int256 proportionalTerm, uint256 accumulatedLeak) internal virtual override {
    watcher.calledInternal(
      abi.encodeWithSignature('_updateDeviationHistory(int256,uint256)', proportionalTerm, accumulatedLeak)
    );
    if (callSuper || callSupper_updateDeviationHistory) {
      super._updateDeviationHistory(proportionalTerm, accumulatedLeak);
    } else {
      mockPIDController.mock_updateDeviationHistory(proportionalTerm, accumulatedLeak);
    }
  }

  bool callSupper_getNextRedemptionRate = true;

  function setCallSupper_getNextRedemptionRate(bool _callSuper) external {
    callSupper_getNextRedemptionRate = _callSuper;
  }

  function _getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) internal view virtual override returns (uint256, int256, int256, uint256) {
    watcher.calledInternal(
      abi.encodeWithSignature(
        '_getNextRedemptionRate(uint256,uint256,uint256)', _marketPrice, _redemptionPrice, _accumulatedLeak
      )
    );
    if (callSuper || callSupper_getNextRedemptionRate) {
      return super._getNextRedemptionRate(_marketPrice, _redemptionPrice, _accumulatedLeak);
    } else {
      return mockPIDController.mock_getNextRedemptionRate(_marketPrice, _redemptionPrice, _accumulatedLeak);
    }
  }

  function call_getProportionalTerm(
    uint256 _marketPrice,
    uint256 _redemptionPrice
  ) external view returns (int256 _proportionalTerm) {
    return _getProportionalTerm(_marketPrice, _redemptionPrice);
  }

  function call_updateDeviationHistory(int256 _proportionalTerm, uint256 _accumulatedLeak) external virtual {
    _updateDeviationHistory(_proportionalTerm, _accumulatedLeak);
  }

  function push_mockDeviationObservation(IPIDController.DeviationObservation memory _deviationObservation) public {
    deviationObservations.push(_deviationObservation);
  }

  function setControllerGains(int256 _kp, int256 _ki) external {
    controllerGains.Kp = _kp;
    controllerGains.Ki = _ki;
  }

  // stdstore not available for int256
  function setPriceDeviationCumulative(int256 _priceDeviationCumulative) external {
    priceDeviationCumulative = _priceDeviationCumulative;
  }

  // stdstore not available for address
  function setSeedProposer(address _seedProposer) external {
    seedProposer = _seedProposer;
  }

  // stdstore not available for uint256
  function setFeedbackOutputLowerBound(int256 _feedbackOutputLowerBound) external {
    feedbackOutputLowerBound = _feedbackOutputLowerBound;
  }
}

contract MockPIDController {
  function mock_getBoundedPIOutput(int256 _piOutput) external view returns (int256 _boundedPIOutput) {}

  function mock_getProportionalTerm(
    uint256 marketPrice,
    uint256 redemptionPrice
  ) external view virtual returns (int256 _proportionalTerm) {}

  function mock_getNextPriceDeviationCumulative(
    int256 proportionalTerm,
    uint256 accumulatedLeak
  ) external view virtual returns (int256 _cumulativeDeviation, int256 _newTimeAdjustedDeviation) {}

  function mock_getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view virtual returns (int256 _gainAdjustedPIOutput) {}

  function mock_breaksNoiseBarrier(
    uint256 _piSum,
    uint256 _redemptionPrice
  ) external view virtual returns (bool _breaks) {}

  function mock_getBoundedRedemptionRate(int256 _piOutput) external view virtual returns (uint256, uint256) {}

  function mock_oll() external view virtual returns (uint256) {}

  function mock_getGainAdjustedTerms(
    int256 proportionalTerm,
    int256 integralTerm
  ) external view virtual returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {}

  function mock_getLastProportionalTerm() external view virtual returns (int256) {}

  function mock_updateDeviationHistory(int256 _proportionalTerm, uint256 _accumulatedLeak) external virtual {}

  function mock_getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external view virtual returns (uint256, int256, int256, uint256) {}
}
