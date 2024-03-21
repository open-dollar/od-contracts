// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

contract InternalCallsWatcher {
  function calledInternal(bytes memory _encodedCall) external view {}
}

contract InternalCallsExtension {
  InternalCallsWatcher public watcher;
  /**
   * @dev This will call super by default. It can be setup according to the test whether needed the original behavior for the
   * purposes of the test or not.
   */
  bool public callSuper = true;

  constructor() {
    watcher = new InternalCallsWatcher();
  }

  function setCallSuper(bool _callSuper) public {
    callSuper = _callSuper;
  }
}
