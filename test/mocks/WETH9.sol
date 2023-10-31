// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

contract WETH9 {
  string public name = 'Wrapped Ether';
  string public symbol = 'WETH';
  uint8 public decimals = 18;

  event Approval(address indexed _owner, address indexed _spender, uint256 _wad);
  event Transfer(address indexed _src, address indexed _dst, uint256 _wad);
  event Deposit(address indexed _dst, uint256 _wad);
  event Withdrawal(address indexed _src, uint256 _wad);

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  receive() external payable {
    deposit();
  }

  function deposit() public payable {
    balanceOf[msg.sender] += msg.value;
    emit Deposit(msg.sender, msg.value);
  }

  function withdraw(uint256 _wad) public {
    require(balanceOf[msg.sender] >= _wad);
    balanceOf[msg.sender] -= _wad;
    payable(msg.sender).transfer(_wad);
    emit Withdrawal(msg.sender, _wad);
  }

  function totalSupply() public view returns (uint256 _totalSupply) {
    return address(this).balance;
  }

  function approve(address _guy, uint256 _wad) public returns (bool _ok) {
    allowance[msg.sender][_guy] = _wad;
    emit Approval(msg.sender, _guy, _wad);
    return true;
  }

  function transfer(address _dst, uint256 _wad) public returns (bool _ok) {
    return transferFrom(msg.sender, _dst, _wad);
  }

  function transferFrom(address _src, address _dst, uint256 _wad) public returns (bool _ok) {
    require(balanceOf[_src] >= _wad);

    if (_src != msg.sender && allowance[_src][msg.sender] != type(uint256).max) {
      require(allowance[_src][msg.sender] >= _wad);
      allowance[_src][msg.sender] -= _wad;
    }

    balanceOf[_src] -= _wad;
    balanceOf[_dst] += _wad;

    emit Transfer(_src, _dst, _wad);

    return true;
  }
}
