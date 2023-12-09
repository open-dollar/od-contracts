// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// Open Dollar
// Version 1.5.8

contract ODProxy {
  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);
  error OnlyOwner();

  event executionTime(uint256 _lastExecution);

  address public immutable OWNER;
  uint256 private _lastExecution;

  constructor(address _owner) {
    OWNER = _owner;
  }

  /**
   * @notice Checks whether msg.sender can call an owned function
   */
  modifier onlyOwner() {
    if (msg.sender != OWNER) revert OnlyOwner();
    _;
  }

  /**
   * @notice Executes a call using logic from the target contract; in the context of this proxy
   * @param _target The address of the target contract
   * @param _data The data to be delegated on the target contract
   * @return _response The response of the call
   */
  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    _lastExecution = block.timestamp;

    bool _succeeded;
    (_succeeded, _response) = _target.delegatecall(_data);

    if (!_succeeded) {
      revert TargetCallFailed(_response);
    }
    emit executionTime(_lastExecution);
  }

  /**
   * @notice Returns the timestamp of the last execution
   */
  function getLastExecution() external view returns (uint256 lastExecution) {
    return _lastExecution;
  }
}
