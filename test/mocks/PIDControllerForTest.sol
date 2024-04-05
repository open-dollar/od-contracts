// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IPIDController, PIDController} from '@contracts/PIDController.sol';
import {InternalCallsWatcher, InternalCallsExtension} from '@test/utils/InternalCallsWatcher.sol';

// solhint-disable
contract PIDControllerForTest is PIDController, InternalCallsExtension {
  MockPIDController public mockPIDController;

  constructor(
    ControllerGains memory _cGains,
    PIDControllerParams memory _pidParams,
    DeviationObservation memory _importedState,
    MockPIDController _mockPIDController
  ) PIDController(_cGains, _pidParams, _importedState) {
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
    return super._getBoundedPIOutput(_piOutput);
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

  bool callSupper_getNextDeviationCumulative = true;

  function setCallSupper_getNextDeviationCumulative(bool _callSuper) external {
    callSupper_getNextDeviationCumulative = _callSuper;
  }

  function _getNextDeviationCumulative(
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
      abi.encodeWithSignature('_getNextDeviationCumulative(int256,uint256)', _proportionalTerm, _accumulatedLeak)
    );
    if (callSuper || callSupper_getNextDeviationCumulative) {
      return super._getNextDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    } else {
      return mockPIDController.mock_getNextDeviationCumulative(_proportionalTerm, _accumulatedLeak);
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

  function _getBoundedRedemptionRate(int256 _piOutput) internal view virtual override returns (uint256) {
    watcher.calledInternal(abi.encodeWithSignature('_getBoundedRedemptionRate(int256)', _piOutput));
    if (callSuper || callSupper_getBoundedRedemptionRate) {
      return super._getBoundedRedemptionRate(_piOutput);
    } else {
      return mockPIDController.mock_getBoundedRedemptionRate(_piOutput);
    }
  }

  bool callSupper_updateDeviation = true;

  function setCallSupper_updateDeviation(bool _callSuper) external {
    callSupper_updateDeviation = _callSuper;
  }

  function _updateDeviation(
    int256 proportionalTerm,
    uint256 accumulatedLeak
  ) internal virtual override returns (int256 _newCumulativeDeviation) {
    watcher.calledInternal(
      abi.encodeWithSignature('_updateDeviation(int256,uint256)', proportionalTerm, accumulatedLeak)
    );
    if (callSuper || callSupper_updateDeviation) {
      return super._updateDeviation(proportionalTerm, accumulatedLeak);
    } else {
      return mockPIDController.mock_updateDeviation(proportionalTerm, accumulatedLeak);
    }
  }

  function call_getProportionalTerm(
    uint256 _marketPrice,
    uint256 _redemptionPrice
  ) external view returns (int256 _proportionalTerm) {
    return super._getProportionalTerm(_marketPrice, _redemptionPrice);
  }

  function call_updateDeviation(int256 _proportionalTerm, uint256 _accumulatedLeak) external virtual {
    super._updateDeviation(_proportionalTerm, _accumulatedLeak);
  }

  // stdstore not available for address
  function setSeedProposer(address _seedProposer) external {
    seedProposer = _seedProposer;
  }
}

contract MockPIDController {
  function mock_getBoundedPIOutput(int256 _piOutput) external view returns (int256 _boundedPIOutput) {}

  function mock_getProportionalTerm(
    uint256 marketPrice,
    uint256 redemptionPrice
  ) external view virtual returns (int256 _proportionalTerm) {}

  function mock_getNextDeviationCumulative(
    int256 proportionalTerm,
    uint256 accumulatedLeak
  ) external view virtual returns (int256 _integralDeviation, int256 _newTimeAdjustedDeviation) {}

  function mock_getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view virtual returns (int256 _gainAdjustedPIOutput) {}

  function mock_breaksNoiseBarrier(
    uint256 _piSum,
    uint256 _redemptionPrice
  ) external view virtual returns (bool _breaks) {}

  function mock_getBoundedRedemptionRate(int256 _piOutput) external view virtual returns (uint256) {}

  function mock_getGainAdjustedTerms(
    int256 proportionalTerm,
    int256 integralTerm
  ) external view virtual returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {}

  function mock_updateDeviation(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) external virtual returns (int256 _newCumulativeDeviation) {}

  function mock_getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external view virtual returns (uint256, int256, int256) {}
}
