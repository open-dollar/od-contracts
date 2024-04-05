// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AIRDROP_AMOUNT, AIRDROP_RECIPIENTS} from '@script/Registry.s.sol';
import {IVotes} from '@openzeppelin/governance/utils/IVotes.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Common, COLLAT, DEBT, TKN} from '@test/e2e/Common.t.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {WAD} from '@libraries/Math.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {MintableVoteERC20} from '@contracts/for-test/MintableVoteERC20.sol';

interface IModifyParameters {
  function modifyParameters(bytes32 _param, bytes memory _data) external;
}

struct UpdatePidControllerParams {
  address seedProposer;
  uint256 noiseBarrier;
  uint256 integralPeriodSize;
  uint256 feedbackOutputUpperBound;
  int256 feedbackOutputLowerBound;
  uint256 perSecondCumulativeLeak;
  int256 kp;
  int256 ki;
}

contract E2EGovernor is Common {
  bytes32 constant NEW_CTYPE = bytes32('NEW');
  uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;
  uint256 constant VOTER_WEIGHT = AIRDROP_AMOUNT / AIRDROP_RECIPIENTS;
  address public NEW_CTYPE_ADDR;

  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams = ICollateralAuctionHouse
    .CollateralAuctionHouseParams({
    minimumBid: WAD, // 1 COINs
    minDiscount: WAD, // no discount
    maxDiscount: 0.9e18, // -10%
    perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR
  });

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

  function setUp() public override {
    super.setUp();
    NEW_CTYPE_ADDR = address(new MintableVoteERC20('NewCoin', 'NEW', 18));
    vm.stopPrank();
  }

  /**
   * @dev Proposal Execution
   */
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

    uint256 propId = odGovernor.propose(targets, values, calldatas, description);
    assertEq(
      propId,
      odGovernor.hashProposal(targets, values, calldatas, descriptionHash),
      '_helperExecuteProp: Prop Id not equal'
    );

    propState = odGovernor.state(propId); // returns 0 (Pending)

    emit log_named_uint('Voting Delay:', odGovernor.votingDelay());
    emit log_named_uint('Voting Period:', odGovernor.votingPeriod());

    assertEq(VOTER_WEIGHT, protocolToken.balanceOf(alice));
    assertEq(VOTER_WEIGHT, protocolToken.balanceOf(bob));
    assertEq(0, protocolVotes.getVotes(alice));
    assertEq(0, protocolVotes.getVotes(bob));

    vm.startPrank(bob);
    protocolVotes.delegate(bob);
    vm.stopPrank();

    assertEq(0, protocolVotes.getVotes(alice));
    assertEq(VOTER_WEIGHT, protocolVotes.getVotes(bob));

    vm.roll(startBlock + 2);
    vm.warp(startTime + 30 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = odGovernor.state(propId);

    vm.startPrank(alice);
    // alice has not delegated her governance tokens - no voter weight
    odGovernor.castVote(propId, 0);
    vm.stopPrank();

    propState = odGovernor.state(propId); // returns 1 (Active)

    vm.startPrank(bob);
    // bob holds 25% of governance tokens
    odGovernor.castVote(propId, 1);
    vm.stopPrank();

    propState = odGovernor.state(propId); // returns 1 (Active)

    vm.roll(startBlock + 17);
    vm.warp(startTime + 255 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = odGovernor.state(propId); // returns 4 (Succeeded)

    bytes32 PROPOSER_ROLE = keccak256('PROPOSER_ROLE');
    bytes32 EXECUTOR_ROLE = keccak256('EXECUTOR_ROLE');

    assertEq(false, timelockController.hasRole(PROPOSER_ROLE, alice));
    assertEq(false, timelockController.hasRole(EXECUTOR_ROLE, alice));

    assertEq(false, timelockController.hasRole(PROPOSER_ROLE, bob));
    assertEq(false, timelockController.hasRole(EXECUTOR_ROLE, bob));

    assertEq(true, timelockController.hasRole(PROPOSER_ROLE, address(odGovernor)));
    assertEq(true, timelockController.hasRole(EXECUTOR_ROLE, address(odGovernor)));

    vm.startPrank(bob);
    odGovernor.queue(targets, values, calldatas, descriptionHash);
    propState = odGovernor.state(propId); // returns 5 (Queued)
    vm.stopPrank();

    vm.startPrank(alice);
    vm.roll(startBlock + 19);
    vm.warp(startTime + 316 seconds);
    emit log_named_uint('Block', block.number);
    emit log_named_uint('Time', block.timestamp);

    propState = odGovernor.state(propId); // returns 5 (Queued)
    odGovernor.execute(targets, values, calldatas, descriptionHash);
    propState = odGovernor.state(propId); // returns 7 (Executed)
    vm.stopPrank();
  }

  /**
   * @dev Generate Collateral Params for Proposal
   */
  function generateAddCollateralProposalParams()
    public
    view
    returns (
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      string memory description,
      bytes32 descriptionHash
    )
  {
    // targets = new address[](2);
    // targets[0] = address(collateralJoinFactory);
    // targets[1] = address(collateralAuctionHouseFactory);

    targets = new address[](1);
    targets[0] = address(collateralJoinFactory);

    // values = new uint256[](2);
    // values[0] = 0;
    // values[1] = 0;

    values = new uint256[](1);
    values[0] = 0;

    bytes memory calldata0 =
      abi.encodeWithSelector(ICollateralJoinFactory.deployCollateralJoin.selector, NEW_CTYPE, NEW_CTYPE_ADDR);

    calldatas = new bytes[](1);
    calldatas[0] = calldata0;

    description = 'Add collateral type';

    descriptionHash = keccak256(bytes(description));
  }

  /**
   * @dev Generate NFTRenderer Params for Proposal
   */
  function generateUpdateNFTRendererProposalParams()
    public
    view
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

  /**
   * @dev Generate PID Controller Params for Proposal
   */
  function generateUpdatePidControllerProposalParams(UpdatePidControllerParams memory params)
    public
    view
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

  /**
   * @dev Generate Block Delay Params for Proposal
   */
  function generateUpdateBlockDelayProposalParams(uint256 blockDelay)
    public
    view
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

  /**
   * @dev Generate Time Delay Params for Proposal
   */
  function generateUpdateTimeDelayProposalParams(uint256 timeDelay)
    public
    view
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

contract E2EGovernorProposal is E2EGovernor {
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
    UpdatePidControllerParams memory _params = UpdatePidControllerParams({
      seedProposer: address(365_420_690),
      noiseBarrier: 1,
      integralPeriodSize: 1,
      feedbackOutputUpperBound: 1,
      feedbackOutputLowerBound: -1,
      perSecondCumulativeLeak: 1,
      kp: int256(1),
      ki: int256(0)
    });

    string[9] memory paramString = [
      'seedProposer',
      'noiseBarrier',
      'integralPeriodSize',
      'feedbackOutputUpperBound',
      'feedbackOutputLowerBound',
      'perSecondCumulativeLeak',
      'kp',
      'ki',
      'priceDeviationCumulative'
    ];

    address[] memory authorizedAccounts = pidController.authorizedAccounts();
    vm.startPrank(authorizedAccounts[0]);
    pidController.modifyParameters(_convertStringToBytes32(paramString[0]), abi.encode(_params.seedProposer));
    pidController.modifyParameters(_convertStringToBytes32(paramString[1]), abi.encode(_params.noiseBarrier));
    pidController.modifyParameters(_convertStringToBytes32(paramString[2]), abi.encode(_params.integralPeriodSize));
    pidController.modifyParameters(
      _convertStringToBytes32(paramString[3]), abi.encode(_params.feedbackOutputUpperBound)
    );
    pidController.modifyParameters(
      _convertStringToBytes32(paramString[4]), abi.encode(_params.feedbackOutputLowerBound)
    );
    pidController.modifyParameters(_convertStringToBytes32(paramString[5]), abi.encode(_params.perSecondCumulativeLeak));
    pidController.modifyParameters(_convertStringToBytes32(paramString[6]), abi.encode(_params.kp));
    pidController.modifyParameters(_convertStringToBytes32(paramString[7]), abi.encode(_params.ki));
    pidController.modifyParameters(_convertStringToBytes32(paramString[8]), abi.encode(int256(1)));
    vm.stopPrank();
    assertEq(pidController.seedProposer(), address(365_420_690), 'incorrect seed proposer');
    assertEq(pidController.params().noiseBarrier, _params.noiseBarrier, 'incorrect noiseBarrier');
    assertEq(pidController.params().integralPeriodSize, _params.integralPeriodSize, 'incorrect integralPeriodSize');
    assertEq(
      pidController.params().feedbackOutputUpperBound,
      _params.feedbackOutputUpperBound,
      'incorrect feedbackOutputUpperBound'
    );
    assertEq(
      pidController.params().feedbackOutputLowerBound,
      _params.feedbackOutputLowerBound,
      'incorrect feedbackOutputLowerBound'
    );
    assertEq(
      pidController.params().perSecondCumulativeLeak,
      _params.perSecondCumulativeLeak,
      'incorrect perSecondCumulativeLeak'
    );
    assertEq(pidController.controllerGains().kp, _params.kp, 'incorrect kp');
    assertEq(pidController.controllerGains().ki, _params.ki, 'incorrect ki');
    assertEq(pidController.deviationObservation().integral, int256(1), 'incorrect deviationObservation');
  }

  function testUpdatePidControllerProposalRevert() public {
    address[] memory authorizedAccounts = pidController.authorizedAccounts();
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    vm.prank(authorizedAccounts[0]);
    pidController.modifyParameters(_convertStringToBytes32('unrecognized param'), abi.encode(100));
  }

  function _convertStringToBytes32(string memory stringToConvert) internal pure returns (bytes32 bytes32String) {
    assembly {
      bytes32String := mload(add(stringToConvert, 32))
    }
  }

  function testUpdateBlockDelayProposal(uint256 blockDelay) public {
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
}

contract E2EGovernorAccessControl is E2EGovernor {
  /**
   * @dev Add Collateral
   */
  function testDeployCollateralJoin() public {
    vm.startPrank(address(timelockController));
    bytes32[] memory _collateralTypesList = collateralJoinFactory.collateralTypesList();
    assertEq(_collateralTypesList.length, 6);
    collateralJoinFactory.deployCollateralJoin(NEW_CTYPE, NEW_CTYPE_ADDR);
    vm.stopPrank();
  }

  /**
   * @dev Update NFT Renderer
   */
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

  /**
   * @dev Update PID Controller
   */
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

  /**
   * @dev Update Block Delay
   */
  function testUpdateBlockDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.updateBlockDelay(1);
    vm.stopPrank();

    assertEq(vault721.blockDelay(), 1, 'Block Delay not set properly');
  }

  /**
   * @dev Update Time Delay
   */
  function testUpdateTimeDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.updateTimeDelay(1);
    vm.stopPrank();

    assertEq(vault721.timeDelay(), 1, 'Time Delay not set properly');
  }
}
