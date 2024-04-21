// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Registry.s.sol';
import {Test} from 'forge-std/Test.sol';
import {VmSafe} from 'forge-std/Script.sol';
import {Params, ParamChecker, OD, ETH_A, JOB_REWARD} from '@script/Params.s.sol';

abstract contract Common is Contracts, Params, Test {
  uint256 internal _chainId;
  uint256 internal _deployerPk = 69; // for tests - from OD
  uint256 internal _governorPK;
  bytes32 internal _systemCoinSalt;
  bytes32 internal _vault721Salt;
  bytes internal _systemCoinInitCode;
  bytes internal _vault721InitCode;
  bool internal _isTest;

  function logGovernor() public runIfFork {
    emit log_named_address('Governor', governor);
  }

  function getChainId() public view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }

  // Exclude anvil from the fork check - Not opt for overriding to avoid obscuring the logic
  // Only relevant if we start a anvil instance outside the tests .eg `forge script DeployAnvil --rpc-url $ANVIL_RPC`
  function onFork() public view returns (bool status) {
    status = !isNetworkAnvil() && isFork();
  }

  function isNetworkAnvil() public view returns (bool) {
    return getChainId() == 31_337;
  }

  function isNetworkArbitrumSepolia() public view returns (bool) {
    return getChainId() == 421_614;
  }

  function isNetworkArbitrumOne() public view returns (bool) {
    return getChainId() == 42_161;
  }

  function getSemiRandSalt() public view returns (bytes32) {
    return keccak256(abi.encode(block.number, block.timestamp));
  }

  function deployEthCollateralContracts() public updateParams {
    // deploy ETHJoin and CollateralAuctionHouse
    ethJoin = new ETHJoin(address(safeEngine), ETH_A);

    collateralAuctionHouseFactory.initializeCollateralType(ETH_A, abi.encode(_collateralAuctionHouseParams[ETH_A]));
    collateralAuctionHouse[ETH_A] =
      ICollateralAuctionHouse(collateralAuctionHouseFactory.collateralAuctionHouses(ETH_A));
    collateralJoin[ETH_A] = CollateralJoin(address(ethJoin));
    safeEngine.addAuthorization(address(ethJoin));
  }

  function deployCollateralContracts(bytes32 _cType) public updateParams {
    // deploy CollateralJoin and CollateralAuctionHouse
    address _delegatee = delegatee[_cType];
    if (_delegatee == address(0)) {
      collateralJoin[_cType] =
        collateralJoinFactory.deployCollateralJoin({_cType: _cType, _collateral: address(collateral[_cType])});
    } else {
      collateralJoin[_cType] = collateralJoinFactory.deployDelegatableCollateralJoin({
        _cType: _cType,
        _collateral: address(collateral[_cType]),
        _delegatee: _delegatee
      });
    }

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(_collateralAuctionHouseParams[_cType]));
    collateralAuctionHouse[_cType] =
      ICollateralAuctionHouse(collateralAuctionHouseFactory.collateralAuctionHouses(_cType));
  }

  function _updateAuthorizationForAllContracts(address removeAddress, address addAddress) internal {
    // base contracts
    _revoke(safeEngine, removeAddress, addAddress);
    _revoke(liquidationEngine, removeAddress, addAddress);
    _revoke(accountingEngine, removeAddress, addAddress);
    _revoke(oracleRelayer, removeAddress, addAddress);

    // auction houses
    _revoke(surplusAuctionHouse, removeAddress, addAddress);
    _revoke(debtAuctionHouse, removeAddress, addAddress);

    // tax
    _revoke(taxCollector, removeAddress, addAddress);
    _revoke(stabilityFeeTreasury, removeAddress, addAddress);

    // tokens
    _revoke(systemCoin, removeAddress, addAddress);

    /// @notice pre-deployed protocolToken
    if (protocolToken.authorizedAccounts(addAddress) != true) {
      protocolToken.addAuthorization(addAddress);
    }
    if (protocolToken.authorizedAccounts(removeAddress) == true) {
      if (protocolToken.authorizedAccounts(address(create2))) protocolToken.removeAuthorization(address(create2));
      protocolToken.removeAuthorization(removeAddress);
    }

    // pid controller
    _revoke(pidController, removeAddress, addAddress);
    _revoke(pidRateSetter, removeAddress, addAddress);

    // token adapters
    _revoke(coinJoin, removeAddress, addAddress);

    // safe manager
    _revoke(safeManager, removeAddress, addAddress);

    /// @notice pre-deployed vault721
    if (vault721.authorizedAccounts(addAddress) != true) {
      vault721.addAuthorization(addAddress);
    }
    if (vault721.authorizedAccounts(removeAddress) == true) {
      if (vault721.authorizedAccounts(address(create2))) vault721.removeAuthorization(address(create2));
      vault721.removeAuthorization(removeAddress);
    }

    if (address(ethJoin) != address(0)) {
      _revoke(ethJoin, removeAddress, addAddress);
    }

    // factories or children
    _revoke(chainlinkRelayerFactory, removeAddress, addAddress);
    _revoke(denominatedOracleFactory, removeAddress, addAddress);
    _revoke(delayedOracleFactory, removeAddress, addAddress);
    _revoke(collateralJoinFactory, removeAddress, addAddress);
    _revoke(collateralAuctionHouseFactory, removeAddress, addAddress);

    // global settlement
    _revoke(globalSettlement, removeAddress, addAddress);
    _revoke(postSettlementSurplusAuctionHouse, removeAddress, addAddress);
    _revoke(settlementSurplusAuctioneer, removeAddress, addAddress);

    // jobs
    _revoke(accountingJob, removeAddress, addAddress);
    _revoke(liquidationJob, removeAddress, addAddress);
    _revoke(oracleJob, removeAddress, addAddress);
  }

  function _revoke(IAuthorizable _contract, address _removeAddress, address addAddress) internal {
    if (addAddress != address(0)) {
      _contract.addAuthorization(addAddress);
    }
    if (_removeAddress == address(0)) {
      _contract.removeAuthorization(_removeAddress);
    }
  }

  function _delegateAllTo(address __delegate) internal {
    // base contracts
    _delegate(safeEngine, __delegate);
    _delegate(liquidationEngine, __delegate);
    _delegate(accountingEngine, __delegate);
    _delegate(oracleRelayer, __delegate);

    // auction houses
    _delegate(surplusAuctionHouse, __delegate);
    _delegate(debtAuctionHouse, __delegate);

    // tax
    _delegate(taxCollector, __delegate);
    _delegate(stabilityFeeTreasury, __delegate);

    // tokens
    _delegate(systemCoin, __delegate);

    if (protocolToken.authorizedAccounts(__delegate) != true) {
      // pre-deployed protocolToken
      _delegate(protocolToken, __delegate);
    }

    // pid controller
    _delegate(pidController, __delegate);
    _delegate(pidRateSetter, __delegate);

    // token adapters
    _delegate(coinJoin, __delegate);

    _delegate(chainlinkRelayerFactory, __delegate);
    _delegate(denominatedOracleFactory, __delegate);
    _delegate(delayedOracleFactory, __delegate);

    _delegate(collateralJoinFactory, __delegate);
    _delegate(collateralAuctionHouseFactory, __delegate);

    if (address(ethJoin) != address(0)) {
      _delegate(ethJoin, __delegate);
    }

    // global settlement
    _delegate(globalSettlement, __delegate);
    _delegate(postSettlementSurplusAuctionHouse, __delegate);
    _delegate(settlementSurplusAuctioneer, __delegate);

    // jobs
    _delegate(accountingJob, __delegate);
    _delegate(liquidationJob, __delegate);
    _delegate(oracleJob, __delegate);
  }

  function _delegate(IAuthorizable _contract, address _target) internal {
    _contract.addAuthorization(_target);
  }

  function deployTokenGovernance() public updateParams {
    // deploy Tokens

    if (!isNetworkAnvil()) {
      address systemCoinAddress = create2.create2deploy(_systemCoinSalt, _systemCoinInitCode);
      systemCoin = ISystemCoin(systemCoinAddress);
    } else {
      systemCoin = new OpenDollar();
      protocolToken = new OpenDollarGovernance();
      protocolToken.initialize('Open Dollar Governance', 'ODG');
    }
    systemCoin.initialize('Open Dollar', 'OD');

    address[] memory members = new address[](0);

    if (isNetworkAnvil()) {
      // deploy governance contracts for anvil
      timelockController = new TimelockController(SEPOLIA_MIN_DELAY, members, members, deployer);
      odGovernor = new ODGovernor(
        TEST_INIT_VOTING_DELAY,
        TEST_INIT_VOTING_PERIOD,
        TEST_INIT_PROP_THRESHOLD,
        TEST_INIT_VOTE_QUORUM,
        address(protocolToken),
        timelockController
      );
      // set governor
      governor = address(timelockController);

      // set odGovernor as PROPOSER_ROLE and EXECUTOR_ROLE
      timelockController.grantRole(timelockController.PROPOSER_ROLE(), address(odGovernor));
      timelockController.grantRole(timelockController.EXECUTOR_ROLE(), address(odGovernor));

      // // revoke deployer from TIMELOCK_ADMIN_ROLE
      timelockController.renounceRole(timelockController.TIMELOCK_ADMIN_ROLE(), deployer);
      protocolToken.mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 500_000_000 ether); // mint 500 million tokens to deployer on anvil to sway the vote.
    }
  }

  function deployContracts() public updateParams {
    // deploy Base contracts
    safeEngine = new SAFEEngine(_safeEngineParams);
    oracleRelayer = new OracleRelayer(address(safeEngine), systemCoinOracle, _oracleRelayerParams);

    surplusAuctionHouse =
      new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _surplusAuctionHouseParams);

    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);

    accountingEngine = new AccountingEngine(
      address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse), _accountingEngineParams
    );

    liquidationEngine = new LiquidationEngine(address(safeEngine), address(accountingEngine), _liquidationEngineParams);

    collateralAuctionHouseFactory =
      new CollateralAuctionHouseFactory(address(safeEngine), address(liquidationEngine), address(oracleRelayer));

    // deploy Token adapters
    coinJoin = new CoinJoin(address(safeEngine), address(systemCoin));
    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
  }

  function deployTaxModule() public updateParams {
    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);

    stabilityFeeTreasury = new StabilityFeeTreasury(
      address(safeEngine), address(accountingEngine), address(coinJoin), _stabilityFeeTreasuryParams
    );
  }

  function deployGlobalSettlement() public updateParams {
    globalSettlement = new GlobalSettlement(
      address(safeEngine),
      address(liquidationEngine),
      address(oracleRelayer),
      address(coinJoin),
      address(collateralJoinFactory),
      address(collateralAuctionHouseFactory),
      address(stabilityFeeTreasury),
      address(accountingEngine),
      _globalSettlementParams
    );

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken), _postSettlementSAHParams);

    settlementSurplusAuctioneer =
      new SettlementSurplusAuctioneer(address(accountingEngine), address(postSettlementSurplusAuctionHouse));
  }

  function _setupGlobalSettlement() internal {
    // setup globalSettlement [auth: disableContract]
    safeEngine.addAuthorization(address(globalSettlement));
    liquidationEngine.addAuthorization(address(globalSettlement));
    stabilityFeeTreasury.addAuthorization(address(globalSettlement));
    accountingEngine.addAuthorization(address(globalSettlement));
    oracleRelayer.addAuthorization(address(globalSettlement));
    coinJoin.addAuthorization(address(globalSettlement));
    collateralJoinFactory.addAuthorization(address(globalSettlement));
    collateralAuctionHouseFactory.addAuthorization(address(globalSettlement)); // [+ terminateAuctionPrematurely]

    // registry
    accountingEngine.modifyParameters('postSettlementSurplusDrain', abi.encode(settlementSurplusAuctioneer));

    // auth
    postSettlementSurplusAuctionHouse.addAuthorization(address(settlementSurplusAuctioneer)); // startAuction
  }

  function _setupContracts() internal {
    // auth
    safeEngine.addAuthorization(address(oracleRelayer)); // modifyParameters
    safeEngine.addAuthorization(address(coinJoin)); // transferInternalCoins
    safeEngine.addAuthorization(address(taxCollector)); // updateAccumulatedRate
    safeEngine.addAuthorization(address(debtAuctionHouse)); // transferInternalCoins [createUnbackedDebt]
    safeEngine.addAuthorization(address(liquidationEngine)); // confiscateSAFECollateralAndDebt
    surplusAuctionHouse.addAuthorization(address(accountingEngine)); // startAuction
    debtAuctionHouse.addAuthorization(address(accountingEngine)); // startAuction
    accountingEngine.addAuthorization(address(liquidationEngine)); // pushDebtToQueue
    protocolToken.addAuthorization(address(debtAuctionHouse)); // mint
    systemCoin.addAuthorization(address(coinJoin)); // mint

    safeEngine.addAuthorization(address(collateralJoinFactory)); // addAuthorization(cJoin child)
  }

  function _setupCollateral(bytes32 _cType) internal {
    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams[_cType]));
    oracleRelayer.initializeCollateralType(_cType, abi.encode(_oracleRelayerCParams[_cType]));
    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liquidationEngineCParams[_cType]));

    taxCollector.initializeCollateralType(_cType, abi.encode(_taxCollectorCParams[_cType]));
    if (_taxCollectorSecondaryTaxReceiver.receiver != address(0)) {
      taxCollector.modifyParameters(_cType, 'secondaryTaxReceiver', abi.encode(_taxCollectorSecondaryTaxReceiver));
    }

    // setup initial price
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function deployOracleFactories() public updateParams {
    chainlinkRelayerFactory = new ChainlinkRelayerFactory();
    denominatedOracleFactory = new DenominatedOracleFactory();
    delayedOracleFactory = new DelayedOracleFactory();
  }

  function deployPIDController() public updateParams {
    pidController = new PIDController({
      _cGains: _pidControllerGains,
      _pidParams: _pidControllerParams,
      _importedState: IPIDController.DeviationObservation(0, 0, 0)
    });

    pidRateSetter = new PIDRateSetter({
      _oracleRelayer: address(oracleRelayer),
      _pidCalculator: address(pidController),
      _pidRateSetterParams: _pidRateSetterParams
    });
  }

  function _setupPIDController() internal {
    // setup registry
    pidController.modifyParameters('seedProposer', abi.encode(pidRateSetter));

    // auth
    oracleRelayer.addAuthorization(address(pidRateSetter));

    // initialize
    pidRateSetter.updateRate();
  }

  function deployJobContracts() public updateParams {
    accountingJob = new AccountingJob(address(accountingEngine), address(stabilityFeeTreasury), JOB_REWARD);
    liquidationJob = new LiquidationJob(address(liquidationEngine), address(stabilityFeeTreasury), JOB_REWARD);
    oracleJob = new OracleJob(address(oracleRelayer), address(pidRateSetter), address(stabilityFeeTreasury), JOB_REWARD);
  }

  function _setupJobContracts() internal {
    stabilityFeeTreasury.setTotalAllowance(address(accountingJob), type(uint256).max);
    stabilityFeeTreasury.setTotalAllowance(address(liquidationJob), type(uint256).max);
    stabilityFeeTreasury.setTotalAllowance(address(oracleJob), type(uint256).max);
  }

  function deployProxyContracts() public updateParams {
    if (!isNetworkAnvil()) {
      address vault721Address = create2.create2deploy(_vault721Salt, _vault721InitCode);
      vault721 = Vault721(vault721Address);
    } else {
      vault721 = new Vault721();
    }
    vault721.initialize(address(timelockController), BLOCK_DELAY, TIME_DELAY);

    safeManager =
      new ODSafeManager(address(safeEngine), address(vault721), address(taxCollector), address(liquidationEngine));
    nftRenderer =
      new NFTRenderer(address(vault721), address(oracleRelayer), address(taxCollector), address(collateralJoinFactory));

    _deployProxyActions();
  }

  function _deployProxyActions() internal {
    basicActions = new BasicActions();
    debtBidActions = new DebtBidActions();
    surplusBidActions = new SurplusBidActions();
    collateralBidActions = new CollateralBidActions();
    postSettlementSurplusBidActions = new PostSettlementSurplusBidActions();
    globalSettlementActions = new GlobalSettlementActions();
    rewardedActions = new RewardedActions();
  }

  modifier updateParams() {
    _getEnvironmentParams();
    _;
    _getEnvironmentParams();
  }

  // @dev: only run function if on fork
  modifier runIfFork() {
    if (onFork()) {
      _;
    }
  }

  // @dev: if in the middle of a active broadcast, call function and restore original caller after execution.
  // @attention: function is responsible for starting and stopping the broadcast it needs
  modifier restoreOriginalCaller() {
    (VmSafe.CallerMode callerMode, address activeBroadcastAddr,) = vm.readCallers();
    bool activeBroadcast = callerMode == VmSafe.CallerMode.RecurrentBroadcast;
    bool activePrank = callerMode == VmSafe.CallerMode.RecurrentPrank;
    if (activeBroadcast) {
      vm.stopBroadcast();
      _;
      vm.startBroadcast(activeBroadcastAddr);
    } else if (activePrank) {
      vm.stopPrank();
      _;
      vm.startPrank(activeBroadcastAddr);
    } else {
      _;
    }
  }
}
