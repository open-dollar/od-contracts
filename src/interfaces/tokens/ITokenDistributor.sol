// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';

interface ITokenDistributor is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a user claims tokens
   * @param  _user Address of the user that claimed
   * @param  _amount Amount of tokens claimed
   */
  event Claimed(address _user, uint256 _amount);

  /**
   * @notice Emitted when the distributor is swept (after the claim period has ended)
   * @param  _sweepReceiver Address that received the swept tokens
   * @param  _amount Amount of tokens swept
   */
  event Swept(address _sweepReceiver, uint256 _amount);

  // --- Errors ---

  /// @notice Throws when trying to sweep before the claim period has ended
  error TokenDistributor_ClaimPeriodNotEnded();
  /// @notice Throws when trying to claim but the claim is not valid
  error TokenDistributor_ClaimInvalid();

  /// @notice The merkle root of the token distribution
  function root() external view returns (bytes32 _root);
  /// @notice Address of the ERC20 token to be distributed
  function token() external view returns (ERC20Votes _token);
  /// @notice Total amount of tokens to be distributed
  function totalClaimable() external view returns (uint256 _totalClaimable);
  /// @notice Timestamp when the claim period starts
  function claimPeriodStart() external view returns (uint256 _claimPeriodStart);
  /// @notice Timestamp when the claim period ends
  function claimPeriodEnd() external view returns (uint256 _claimPeriodEnd);

  /**
   * @notice Checks if a user can claim tokens
   * @param  _proof Array of bytes32 merkle proof hashes
   * @param  _user Address of the user to check
   * @param  _amount Amount of tokens to check
   * @return _claimable Whether the user can claim the amount with the proof provided
   */
  function canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) external view returns (bool _claimable);

  /**
   * @notice Claims tokens from the distributor
   * @param  _proof Array of bytes32 merkle proof hashes
   * @param  _amount Amount of tokens to claim
   */
  function claim(bytes32[] calldata _proof, uint256 _amount) external;

  /**
   * @notice Claims tokens from the distributor and delegates them using a signature
   * @param  _proof Array of bytes32 merkle proof hashes
   * @param  _amount Amount of tokens to claim
   * @param  _delegatee Address to delegate the token votes to
   * @param  _expiry Expiration timestamp of the signature
   * @param  _v Recovery byte of the signature
   * @param  _r ECDSA signature r value
   * @param  _s ECDSA signature s value
   */
  function claimAndDelegate(
    bytes32[] calldata _proof,
    uint256 _amount,
    address _delegatee,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external;

  /**
   * @notice Mapping containing the users that have already claimed
   * @param  _user Address of the user to check
   * @return _claimed Boolean indicating if the user has claimed
   */
  function claimed(address _user) external view returns (bool _claimed);

  /**
   * @notice Withdraws tokens from the distributor to a given address after the claim period has ended
   * @param  _sweepReceiver Address to send the tokens to
   */
  function sweep(address _sweepReceiver) external;
}
