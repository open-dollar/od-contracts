pragma solidity 0.6.7;

contract DummyPIDCalculator {
  uint256 internal constant TWENTY_SEVEN_DECIMAL_NUMBER = 10 ** 27;
  uint256 internal constant _rt = 1;

  function computeRate(uint256, uint256, uint256) external virtual returns (uint256) {
    return TWENTY_SEVEN_DECIMAL_NUMBER;
  }

  function rt(uint256, uint256, uint256) external view virtual returns (uint256) {
    return _rt;
  }

  function pscl() external view virtual returns (uint256) {
    return TWENTY_SEVEN_DECIMAL_NUMBER;
  }

  function tlv() external view virtual returns (uint256) {
    return 1;
  }

  function adat() external view virtual returns (uint256) {
    return 0;
  }
}
