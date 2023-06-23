// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';

interface ITokenDistributor is IAuthorizable {
  event Claimed(address _user, uint256 _amount);
  event Swept(address _sweepReceiver, uint256 _amount);
  event Withdrawn(address _to, uint256 _amount);

  error TokenDistributor_ClaimPeriodNotStarted();
  error TokenDistributor_ClaimPeriodEnded();
  error TokenDistributor_AlreadyClaimed();
  error TokenDistributor_ZeroAmount();
  error TokenDistributor_FailedMerkleProofVerify();
  error TokenDistributor_ClaimPeriodNotEnded();

  function root() external view returns (bytes32 _root);
  function token() external view returns (ERC20Votes _token);
  function totalClaimable() external view returns (uint256 _totalClaimable);
  function claimPeriodStart() external view returns (uint256 _claimPeriodStart);
  function claimPeriodEnd() external view returns (uint256 _claimPeriodEnd);
  function canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) external view returns (bool _claimable);
  function claim(bytes32[] calldata _proof, uint256 _amount) external;
  function claimAndDelegate(
    bytes32[] calldata _proof,
    uint256 _amount,
    address _delegatee,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external;
  function claimed(address _user) external view returns (bool _claimed);
  function sweep(address _sweepReceiver) external;
  function withdraw(address _to, uint256 _amount) external;
}
