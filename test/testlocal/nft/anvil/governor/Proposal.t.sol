// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IVotes} from '@openzeppelin/governance/utils/IVotes.sol';
import {AnvilFork} from '@testlocal/nft/anvil/AnvilFork.t.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {WAD} from '@libraries/Math.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

// forge t --fork-url http://127.0.0.1:8545 --match-contract GovernanceProposalAnvil -vvvvv

interface IModifyParameters {
  function modifyParameters(bytes32 _param, bytes memory _data) external;
}

contract GovernanceProposalAnvil is AnvilFork {
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

  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams = ICollateralAuctionHouse
    .CollateralAuctionHouseParams({
    minimumBid: WAD, // 1 COINs
    minDiscount: WAD, // no discount
    maxDiscount: 0.9e18, // -10%
    perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR
  });

  //// Add Collateral ////
  function testDeployCollateralJoin() public {
    vm.startPrank(address(timelockController));
    bytes32[] memory _collateralTypesList = collateralJoinFactory.collateralTypesList();
    collateralJoinFactory.deployCollateralJoin(newCType, newCAddress);
    vm.stopPrank();
  }

  function testDeployCollateralAuctionHouse() public {
    vm.startPrank(address(timelockController));
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(newCType, _cahCParams);
    vm.stopPrank();
  }

  //// Update NFT Renderer ////
  function testUpdateNFTRenderer() public {
    vm.startPrank(vault721.timelockController());
    address fakeOracleRelayer = address(1);
    address fakeTaxCollector = address(2);
    address fakeCollateralJoinFactory = address(3);
    NFTRenderer newNFTRenderer =
      new NFTRenderer(address(vault721), fakeOracleRelayer, fakeTaxCollector, fakeCollateralJoinFactory);
    vault721.updateNftRenderer(address(newNFTRenderer), fakeOracleRelayer, fakeTaxCollector, fakeCollateralJoinFactory);
    vm.stopPrank();
  }

  //// Update PID Controller ////
  function testUpdatePidController() public {
    address[] memory authorizedAccounts = pidController.authorizedAccounts();
    vm.startPrank(authorizedAccounts[0]);
    pidController.modifyParameters('seedProposer', abi.encode(address(365_420_690)));
    pidController.modifyParameters('noiseBarrier', abi.encode(1));
    pidController.modifyParameters('integralPeriodSize', abi.encode(1));
    pidController.modifyParameters('feedbackOutputUpperBound', abi.encode(1));
    pidController.modifyParameters('feedbackOutputLowerBound', abi.encode(-1));
    pidController.modifyParameters('perSecondCumulativeLeak', abi.encode(1));
    pidController.modifyParameters('kp', abi.encode(1));
    pidController.modifyParameters('ki', abi.encode(1));
    vm.stopPrank();

    {
      IPIDController.PIDControllerParams memory params = pidController.params();
      assertEq(pidController.seedProposer(), address(365_420_690));
      assertEq(params.noiseBarrier, 1);
      assertEq(params.integralPeriodSize, 1);
      assertEq(params.feedbackOutputUpperBound, 1);
      assertEq(params.feedbackOutputLowerBound, -1);
      assertEq(params.perSecondCumulativeLeak, 1);
    }

    {
      IPIDController.ControllerGains memory controllerGains = pidController.controllerGains();
      assertEq(controllerGains.kp, 1);
      assertEq(controllerGains.ki, 1);
    }
  }

  //// Update Block Delay ////
  function testUpdateBlockDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.updateBlockDelay(1);
    vm.stopPrank();

    assertEq(vault721.blockDelay(), 1, 'testUpdateBlockDelay: Block Delay not set properly');
  }

  //// Update Time Delay ////
  function testUpdateTimeDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.updateTimeDelay(1);
    vm.stopPrank();

    assertEq(vault721.timeDelay(), 1, 'testUpdateTimeDelay: Time Delay not set properly');
  }

  function _helperExecuteProp(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    bytes32 descriptionHash
  ) public {
    IVotes protocolVotes = IVotes(address(protocolToken));

    uint256 startBlock = block.number;
    uint256 startTime = block.timestamp;
    emit log_named_uint('Block', startBlock);
    emit log_named_uint('Time', startTime);
    ODGovernor dao = ODGovernor(payable(ODGovernor_Address));

    uint256 propId = dao.propose(targets, values, calldatas, description);
    assertEq(
      propId, dao.hashProposal(targets, values, calldatas, descriptionHash), '_helperExecuteProp: Prop Id not equal'
    );

    propState = dao.state(propId); // returns 0 (Pending)

    emit log_named_uint('Voting Delay:', dao.votingDelay());
    emit log_named_uint('Voting Period:', dao.votingPeriod());

    assertEq(3_333_333_333_333_333_333_333, protocolToken.balanceOf(ALICE));
    assertEq(3_333_333_333_333_333_333_333, protocolToken.balanceOf(BOB));
    assertEq(0, protocolVotes.getVotes(ALICE));
    assertEq(0, protocolVotes.getVotes(BOB));

    vm.startPrank(BOB);
    protocolVotes.delegate(BOB);
    vm.stopPrank();

    assertEq(0, protocolVotes.getVotes(ALICE));
    assertEq(3_333_333_333_333_333_333_333, protocolVotes.getVotes(BOB));

    vm.roll(startBlock + 2);
    vm.warp(startTime + 30 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = dao.state(propId);

    vm.startPrank(ALICE);
    // ALICE holds no governance tokens, so should not effect outcome
    dao.castVote(propId, 0);
    vm.stopPrank();

    propState = dao.state(propId); // returns 1 (Active)

    vm.startPrank(BOB);
    // BOB holds 33% of governance tokens
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

    assertEq(false, timelockController.hasRole(PROPOSER_ROLE, ALICE));
    assertEq(false, timelockController.hasRole(EXECUTOR_ROLE, ALICE));

    assertEq(false, timelockController.hasRole(PROPOSER_ROLE, BOB));
    assertEq(false, timelockController.hasRole(EXECUTOR_ROLE, BOB));

    assertEq(true, timelockController.hasRole(PROPOSER_ROLE, address(dao)));
    assertEq(true, timelockController.hasRole(EXECUTOR_ROLE, address(dao)));

    vm.startPrank(BOB);
    dao.queue(targets, values, calldatas, descriptionHash);
    propState = dao.state(propId); // returns 5 (Queued)
    vm.stopPrank();

    vm.startPrank(ALICE);
    vm.roll(startBlock + 19);
    vm.warp(startTime + 316 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = dao.state(propId); // returns 5 (Queued)
    dao.execute(targets, values, calldatas, descriptionHash);
    propState = dao.state(propId); // returns 7 (Executed)
    vm.stopPrank();
  }

  // test governance process
  function testAddCollateralProposal() public {
    (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    ) = generateAddCollateralProposalParams();
    _helperExecuteProp(targets, values, calldatas, description, descriptionHash);
  }

  function testUpdateNFTRendererProposal() public {
    (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    ) = generateUpdateNFTRendererProposalParams();
    _helperExecuteProp(targets, values, calldatas, description, descriptionHash);
  }

  function testUpdatePidControllerProposal() public {
    (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    ) = generateUpdatePidControllerProposalParams(
      UpdatePidControllerParams({
        seedProposer: address(365_420_690),
        noiseBarrier: 1,
        integralPeriodSize: 1,
        feedbackOutputUpperBound: 1,
        feedbackOutputLowerBound: -1,
        perSecondCumulativeLeak: 1,
        kp: 1,
        ki: 1
      })
    );

    address[] memory authorizedAccounts = pidController.authorizedAccounts();
    ODGovernor dao = ODGovernor(payable(ODGovernor_Address));
    vm.startPrank(authorizedAccounts[0]);
    pidController.addAuthorization(address(dao));
    vm.stopPrank();

    _helperExecuteProp(targets, values, calldatas, description, descriptionHash);
  }

  function testUpdateBlockDelayProposal(uint8 blockDelay) public {
    (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    ) = generateUpdateBlockDelayProposalParams(blockDelay);
    _helperExecuteProp(targets, values, calldatas, description, descriptionHash);

    assertEq(vault721.blockDelay(), blockDelay, 'testUpdateBlockDelayProposal: Block Delay not set properly');
  }

  function testUpdateTimeDelayProposal(uint256 timeDelay) public {
    (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    ) = generateUpdateTimeDelayProposalParams(timeDelay);
    _helperExecuteProp(targets, values, calldatas, description, descriptionHash);

    assertEq(vault721.timeDelay(), timeDelay, 'testUpdateTimeDelayProposal: Time Delay not set properly');
  }

  //// Proposal Paarams ////
  function generateAddCollateralProposalParams()
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

    bytes memory calldata0 =
      abi.encodeWithSelector(ICollateralJoinFactory.deployCollateralJoin.selector, newCType, newCAddress);

    bytes memory calldata1 = abi.encodeWithSelector(
      ICollateralAuctionHouseFactory.deployCollateralAuctionHouse.selector, newCType, _cahCParams
    );

    calldatas = new bytes[](2);
    calldatas[0] = calldata0;
    calldatas[1] = calldata1;

    description = 'Add collateral type';

    descriptionHash = keccak256(bytes(description));
  }

  function generateUpdateNFTRendererProposalParams()
    public
    returns (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    )
  {
    targets = new address[](1);
    targets[0] = address(vault721);

    values = new uint256[](1);
    values[0] = 0;

    bytes memory calldata0 = abi.encodeWithSelector(
      IVault721.updateNftRenderer.selector,
      address(nftRenderer),
      address(oracleRelayer),
      address(taxCollector),
      address(collateralJoinFactory)
    );

    calldatas = new bytes[](1);
    calldatas[0] = calldata0;

    description = 'Update NFT Renderer';

    descriptionHash = keccak256(bytes(description));
  }

  struct UpdatePidControllerParams {
    address seedProposer;
    uint256 noiseBarrier;
    uint256 integralPeriodSize;
    uint256 feedbackOutputUpperBound;
    int256 feedbackOutputLowerBound;
    uint256 perSecondCumulativeLeak;
    uint256 kp;
    uint256 ki;
  }

  function generateUpdatePidControllerProposalParams(UpdatePidControllerParams memory params)
    public
    returns (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    )
  {
    targets = new address[](8);
    targets[0] = address(pidController);
    targets[1] = address(pidController);
    targets[2] = address(pidController);
    targets[3] = address(pidController);
    targets[4] = address(pidController);
    targets[5] = address(pidController);
    targets[6] = address(pidController);
    targets[7] = address(pidController);

    values = new uint256[](8);
    values[0] = 0;
    values[1] = 0;
    values[2] = 0;
    values[3] = 0;
    values[4] = 0;
    values[5] = 0;
    values[6] = 0;
    values[7] = 0;

    bytes4 selector = IModifyParameters.modifyParameters.selector;
    calldatas = new bytes[](8);
    calldatas[0] = abi.encodeWithSelector(selector, 'seedProposer', abi.encode(params.seedProposer));
    calldatas[1] = abi.encodeWithSelector(selector, 'noiseBarrier', abi.encode(params.noiseBarrier));
    calldatas[2] = abi.encodeWithSelector(selector, 'integralPeriodSize', abi.encode(params.integralPeriodSize));
    calldatas[3] =
      abi.encodeWithSelector(selector, 'feedbackOutputUpperBound', abi.encode(params.feedbackOutputUpperBound));
    calldatas[4] =
      abi.encodeWithSelector(selector, 'feedbackOutputLowerBound', abi.encode(params.feedbackOutputLowerBound));
    calldatas[5] =
      abi.encodeWithSelector(selector, 'perSecondCumulativeLeak', abi.encode(params.perSecondCumulativeLeak));
    calldatas[6] = abi.encodeWithSelector(selector, 'kp', abi.encode(params.kp));
    calldatas[7] = abi.encodeWithSelector(selector, 'ki', abi.encode(params.ki));

    description = 'Update PID Controller';

    descriptionHash = keccak256(bytes(description));
  }

  function generateUpdateBlockDelayProposalParams(uint8 blockDelay)
    public
    returns (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    )
  {
    targets = new address[](1);
    targets[0] = address(vault721);

    values = new uint256[](1);
    values[0] = 0;

    bytes memory calldata0 = abi.encodeWithSelector(IVault721.updateBlockDelay.selector, blockDelay);

    calldatas = new bytes[](1);
    calldatas[0] = calldata0;

    description = 'Update Block Delay';

    descriptionHash = keccak256(bytes(description));
  }

  function generateUpdateTimeDelayProposalParams(uint256 timeDelay)
    public
    returns (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    )
  {
    targets = new address[](1);
    targets[0] = address(vault721);

    values = new uint256[](1);
    values[0] = 0;

    bytes memory calldata0 = abi.encodeWithSelector(IVault721.updateTimeDelay.selector, timeDelay);

    calldatas = new bytes[](1);
    calldatas[0] = calldata0;

    description = 'Update Time Delay';

    descriptionHash = keccak256(bytes(description));
  }
}
