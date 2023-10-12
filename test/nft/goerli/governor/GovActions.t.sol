// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GoerliFork} from '@test/nft/goerli/GoerliFork.t.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {WAD, RAY, RAD} from '@libraries/Math.sol';

// forge t --fork-url $URL --match-contract GovActions -vvvvv

contract GovActions is GoerliFork {
  uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;

  /**
   * @dev params for testing, do not use for production
   */
  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams = ICollateralAuctionHouse
    .CollateralAuctionHouseParams({
    minimumBid: WAD, // 1 COINs
    minDiscount: WAD, // no discount
    maxDiscount: 0.9e18, // -10%
    perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR
  });

  /**
   * @dev tests are grouped into 1 function to avoid being run general test
   * change `X_all` to `test_all` to run tests in this contract
   */
  function X_all() public {
    t_executeProp();
  }

  // tests
  function t_executeProp() public {
    uint256 startBlock = block.number;
    uint256 startTime = block.timestamp;
    emit log_named_uint('Block', startBlock);
    emit log_named_uint('Time', startTime);
    ODGovernor dao = ODGovernor(payable(ODGovernor_Address));
    (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    ) = generateParams();

    uint256 propId = dao.propose(targets, values, calldatas, description);
    assertEq(propId, dao.hashProposal(targets, values, calldatas, descriptionHash));

    // ODGovernor.ProposalState memory propState = dao.state();

    emit log_named_uint('Voting Delay:', dao.votingDelay());
    emit log_named_uint('Voting Period:', dao.votingPeriod());

    vm.roll(startBlock + 2);
    vm.warp(startTime + 30 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    vm.startPrank(alice);
    // alice holds no governance tokens, so should not effect outcome
    dao.castVote(propId, 0);
    vm.stopPrank();

    vm.startPrank(bob);
    // bob holds 33% of governance tokens
    dao.castVote(propId, 1);
    vm.stopPrank();

    vm.roll(startBlock + 17);
    vm.warp(startTime + 255 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    // TODO: pass `execute`
    dao.execute(targets, values, calldatas, descriptionHash);
  }

  // helpers
  function generateParams()
    public
    returns (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    )
  {
    targets = new address[](2);
    targets[0] = address(collateralJoinFactory);
    targets[1] = address(collateralAuctionHouseFactory);

    values = new uint256[](2);
    values[0] = 0;
    values[1] = 0;

    bytes memory calldata0 = abi.encodeWithSignature('deployCollateralJoin(bytes32,address)', cType, cAddr);
    bytes memory calldata1 = abi.encodeWithSignature(
      'deployCollateralAuctionHouse(bytes32,ICollateralAuctionHouse.CollateralAuctionHouseParams)', cType, _cahCParams
    );

    calldatas = new bytes[](2);
    calldatas[0] = calldata0;
    calldatas[1] = calldata1;

    description = 'Add collateral type';

    descriptionHash = keccak256(bytes(description));
  }
}
