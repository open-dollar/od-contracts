pragma solidity 0.8.19;

contract OracleForTest {
  uint256 price = 1 ether;
  bool validity = true;

  function getResultWithValidity() public view returns (uint256 _price, bool _validity) {
    _price = price;
    _validity = validity;
  }

  function setPriceAndValidity(uint256 _price, bool _validity) public {
    price = _price;
    validity = _validity;
  }

  function priceSource() public pure returns (address) {
    return address(0);
  }
}
