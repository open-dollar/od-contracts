// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IVotes} from '@openzeppelin/governance/utils/IVotes.sol';
import {GoerliFork} from '@testlocal//nft/goerli/GoerliFork.t.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {WAD, RAY, RAD} from '@libraries/Math.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';

// forge t --fork-url $URL --match-contract AddCollateralGoerli -vvvvv

contract AddCollateralGoerli is GoerliFork {
  uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;
  /**
   * @notice ProposalState:
   * Pending = 0
   * Active = 1
   * Canceled = 2
   * Defeated = 3
   * Succeeded = 4
   * Queued = 5
   * Expired = 6
   * Executed = 7
   */
  IGovernor.ProposalState public propState;

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

  // test access control
  function testAddCollateral() public {
    vm.startPrank(address(timelockController));
    bytes32[] memory _collateralTypesList = collateralJoinFactory.collateralTypesList();
    collateralJoinFactory.deployCollateralJoin(bytes32('WETH'), 0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f);
    vm.stopPrank();
  }

  function testDeployCollateralAuctionHouse() public {
    vm.startPrank(address(timelockController));
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(bytes32('WETH'), _cahCParams);
    vm.stopPrank();
  }

  // test governance process
  function testExecuteProp() public {
    IVotes protocolVotes = IVotes(address(protocolToken));

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

    propState = dao.state(propId); // returns 0 (Pending)

    emit log_named_uint('Voting Delay:', dao.votingDelay());
    emit log_named_uint('Voting Period:', dao.votingPeriod());

    assertEq(0, protocolToken.balanceOf(alice));
    assertEq(3_333_333_333_333_333_333_333, protocolToken.balanceOf(bob));
    assertEq(0, protocolVotes.getVotes(alice));
    assertEq(0, protocolVotes.getVotes(bob));

    vm.startPrank(bob);
    protocolVotes.delegate(bob);
    vm.stopPrank();

    assertEq(0, protocolVotes.getVotes(alice));
    assertEq(3_333_333_333_333_333_333_333, protocolVotes.getVotes(bob));

    vm.roll(startBlock + 2);
    vm.warp(startTime + 30 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = dao.state(propId);

    vm.startPrank(alice);
    // alice holds no governance tokens, so should not effect outcome
    dao.castVote(propId, 0);
    vm.stopPrank();

    propState = dao.state(propId); // returns 1 (Active)

    vm.startPrank(bob);
    // bob holds 33% of governance tokens
    dao.castVote(propId, 1);
    vm.stopPrank();

    propState = dao.state(propId); // returns 1 (Active)

    vm.roll(startBlock + 17);
    vm.warp(startTime + 255 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = dao.state(propId); // returns 4 (Succeeded)

    bytes32 PROPOSER_ROLE = keccak256('PROPOSER_ROLE');
    bytes32 EXECUTOR_ROLE = keccak256('EXECUTOR_ROLE');

    assertEq(false, timelockController.hasRole(PROPOSER_ROLE, alice));
    assertEq(false, timelockController.hasRole(EXECUTOR_ROLE, alice));

    assertEq(false, timelockController.hasRole(PROPOSER_ROLE, bob));
    assertEq(false, timelockController.hasRole(EXECUTOR_ROLE, bob));

    vm.startPrank(bob);
    dao.queue(targets, values, calldatas, descriptionHash);

    propState = dao.state(propId); // returns 5 (Queued)

    vm.roll(startBlock + 1);
    vm.warp(startTime + 315 seconds);

    dao.execute(targets, values, calldatas, descriptionHash);

    propState = dao.state(propId); // returns # ()
    vm.stopPrank();
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

    bytes memory calldata0 = abi.encodeWithSignature(
      'deployCollateralJoin(bytes32,address)', bytes32('WETH'), 0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f
    );
    bytes memory calldata1 = abi.encodeWithSignature(
      'deployCollateralAuctionHouse(bytes32,ICollateralAuctionHouse.CollateralAuctionHouseParams)',
      bytes32('WETH'),
      _cahCParams
    );

    calldatas = new bytes[](2);
    calldatas[0] = calldata0;
    calldatas[1] = calldata1;

    description = 'Add collateral type';

    descriptionHash = keccak256(bytes(description));
  }
}
