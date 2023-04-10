pragma solidity 0.6.7;

contract DummyPIDCalculator {
  uint constant internal TWENTY_SEVEN_DECIMAL_NUMBER = 10**27;
  uint constant internal _rt = 1;

  function computeRate(uint256, uint256, uint256) virtual external returns (uint256) {
      return TWENTY_SEVEN_DECIMAL_NUMBER;
  }
  function rt(uint256, uint256, uint256) virtual external view returns (uint256) {
      return _rt;
  }
  function pscl() virtual external view returns (uint256) {
      return TWENTY_SEVEN_DECIMAL_NUMBER;
  }
  function tlv() virtual external view returns (uint256) {
      return 1;
  }
  function adat() virtual external view returns (uint256) {
      return 0;
  }
}
