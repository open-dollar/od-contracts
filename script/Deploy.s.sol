// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Registry.s.sol';
import '@script/Params.s.sol';
import 'forge-std/console2.sol';
import {Script, VmSafe} from 'forge-std/Script.sol';
import {FixedPointMathLib} from '@isolmate/utils/FixedPointMathLib.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {Common} from '@script/Common.s.sol';
import {SepoliaParams} from '@script/SepoliaParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

abstract contract Deploy is Common, Script {
  function _addAuthCreate2AndProtocolToken() public runIfFork restoreOriginalCaller {
    address deployerAddr = vm.addr(_deployerPk);
    address create2AuthAddr = create2.authorizedAccounts()[0];
    address protocolTokenAuthAddr = protocolToken.authorizedAccounts()[0];
    vm.startBroadcast(create2AuthAddr);
    if (!_isAuth(address(create2), deployerAddr)) {
      create2.addAuthorization(deployerAddr);
    }
    vm.stopBroadcast();
    vm.startBroadcast(protocolTokenAuthAddr);
    if (!_isAuth(address(protocolToken), deployerAddr)) {
      protocolToken.addAuthorization(deployerAddr);
    }
    vm.stopBroadcast();
  }

  function _isAuth(address _contract, address _account) public view returns (bool b) {
    b = IAuthorizable(_contract).authorizedAccounts(_account);
  }

  function run() public {
    deployer = vm.addr(_deployerPk);

    if (_isTest) {
      vm.startPrank(deployer);
    } else {
      vm.startBroadcast(deployer);
    }

    // creation bytecode
    _systemCoinInitCode = type(OpenDollar).creationCode;
    _vault721InitCode = type(Vault721).creationCode;

    //print the commit hash
    string[] memory inputs = new string[](3);
    inputs[0] = 'git';
    inputs[1] = 'rev-parse';
    inputs[2] = 'HEAD';

    _addAuthCreate2AndProtocolToken();
    // Deploy oracle factories used to setup the environment
    deployOracleFactories();
    // Environment may be different for each network
    setupEnvironment();
    // Common deployment routine for all networks
    deployTokenGovernance();
    deployContracts();
    deployTaxModule();
    _setupContracts();
    deployGlobalSettlement();
    _setupGlobalSettlement();
    // PID Controller contracts
    deployPIDController();
    _setupPIDController();
    // Rewarded Actions contracts
    deployJobContracts();
    _setupJobContracts();
    // Deploy collateral contracts
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      if (_cType == ETH_A) deployEthCollateralContracts();
      else deployCollateralContracts(_cType);
      _setupCollateral(_cType);
    }
    // Mint initial ODG airdrop E2E or Anvil
    if (isFork() && isNetworkAnvil()) {
      protocolToken.mint(address(0x420), AIRDROP_AMOUNT / AIRDROP_RECIPIENTS);
      protocolToken.mint(address(0x421), AIRDROP_AMOUNT / AIRDROP_RECIPIENTS);
    }

    // Deploy contracts related to the SafeManager usecase
    deployProxyContracts();
    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    if (!isNetworkAnvil()) {
      _updateAuthorizationForAllContracts(deployer, tlc_gov);
    } else {
      _delegateAllTo(tlc_gov);
    }

    if (_isTest) {
      vm.stopPrank();
    }
  }

  // abstract methods to be overridden by network-specific deployments
  function setupEnvironment() public virtual {}
  function setupPostEnvironment() public virtual {}
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    if (!isNetworkArbitrumOne()) {
      revert('DeployMainnet: network is not Arbitrum One');
    }

    // set create2 factory
    create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);
    protocolToken = IProtocolToken(MAINNET_PROTOCOL_TOKEN);
    tlc_gov = MAINNET_TIMELOCK_CONTROLLER;
    timelockController = TimelockController(payable(MAINNET_TIMELOCK_CONTROLLER));
    odGovernor = ODGovernor(payable(MAINNET_OD_GOVERNOR));

    _deployerPk = uint256(vm.envBytes32('ARB_MAINNET_DEPLOYER_PK'));
    chainId = 42_161;
    _systemCoinSalt = MAINNET_SALT_SYSTEMCOIN;
    _vault721Salt = MAINNET_SALT_VAULT721;
  }

  // Setup oracle feeds
  function setupEnvironment() public virtual override updateParams {
    IBaseOracle _arbUSDPriceFeed = IBaseOracle(MAINNET_CHAINLINK_ARB_USD_RELAYER);
    IBaseOracle _wstethUSDPriceFeed = IBaseOracle(MAINNET_DENOMINATED_WSTETH_USD_ORACLE);
    IBaseOracle _rethUSDPriceFeed = IBaseOracle(MAINNET_DENOMINATED_RETH_USD_ORACLE);
    if (!isNetworkArbitrumOne()) {
      // to USD
      IBaseOracle _ethUSDPriceFeed =
        chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_PROD);

      IBaseOracle _arbUSDPriceFeed =
        chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_ARB_USD_FEED, ORACLE_INTERVAL_PROD);

      // to ETH
      IBaseOracle _wstethETHPriceFeed =
        chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_WSTETH_ETH_FEED, ORACLE_INTERVAL_PROD);

      IBaseOracle _rethETHPriceFeed =
        chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_RETH_ETH_FEED, ORACLE_INTERVAL_PROD);

      // denominations
      IBaseOracle _wstethUSDPriceFeed =
        denominatedOracleFactory.deployDenominatedOracle(_wstethETHPriceFeed, _ethUSDPriceFeed, false);

      IBaseOracle _rethUSDPriceFeed =
        denominatedOracleFactory.deployDenominatedOracle(_rethETHPriceFeed, _ethUSDPriceFeed, false);
    }

    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_arbUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, ORACLE_INTERVAL_PROD);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_rethUSDPriceFeed, ORACLE_INTERVAL_PROD);

    systemCoinOracle = new OracleForTest(OD_INITIAL_PRICE); // 1 OD = 1 USD

    collateral[ARB] = IERC20Metadata(ARBITRUM_ARB);
    collateral[WSTETH] = IERC20Metadata(ARBITRUM_WSTETH);
    collateral[RETH] = IERC20Metadata(ARBITRUM_RETH);

    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(RETH);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeploySepolia is SepoliaParams, Deploy {
  using FixedPointMathLib for uint256;

  IBaseOracle public chainlinkEthUSDPriceFeed;

  function setUp() public virtual {
    if (!isNetworkArbitrumSepolia()) {
      revert('DeploySepolia: network is not Arbitrum Sepolia');
    }

    chainId = 421_614;
    // set create2 factory
    create2 = IODCreate2Factory(TEST_CREATE2FACTORY);
    protocolToken = IProtocolToken(SEPOLIA_PROTOCOL_TOKEN);
    tlc_gov = SEPOLIA_TIMELOCK_CONTROLLER;
    timelockController = TimelockController(payable(SEPOLIA_TIMELOCK_CONTROLLER));
    odGovernor = ODGovernor(payable(SEPOLIA_OD_GOVERNOR));

    _deployerPk = uint256(vm.envBytes32('ARB_SEPOLIA_DEPLOYER_PK'));

    _systemCoinSalt = SEPOLIA_SALT_SYSTEMCOIN;
    _vault721Salt = SEPOLIA_SALT_VAULT721;
  }

  // Setup oracle feeds
  function setupEnvironment() public virtual override updateParams {
    // OD
    systemCoinOracle = new OracleForTestnet(OD_INITIAL_PRICE); // 1 OD = 1 USD 'OD / USD'

    // Test tokens (various decimals for testing)
    collateral[ARB] = new MintableVoteERC20('Arbitrum', 'ARB', 18);
    collateral[WSTETH] = new MintableERC20('Wrapped liquid staked Ether 2.0', 'wstETH', 8);
    collateral[CBETH] = new MintableERC20('Coinbase Wrapped Staked ETH', 'cbETH', 8);
    collateral[RETH] = new MintableERC20('Rocket Pool ETH', 'rETH', 3);

    // to USD - Sepolia does not have Chainlink feeds now
    chainlinkEthUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(SEPOLIA_CHAINLINK_ETH_USD_FEED, ORACLE_INTERVAL_TEST);

    // to ETH
    OracleForTestnet _arbETHPriceFeed = new OracleForTestnet(GOERLI_ARB_ETH_PRICE_FEED);

    // denominations
    IBaseOracle _arbUSDPriceFeed =
      denominatedOracleFactory.deployDenominatedOracle(_arbETHPriceFeed, chainlinkEthUSDPriceFeed, false);

    IBaseOracle _rethETHOracle = new OracleForTestnet(0.98e18);
    IBaseOracle _rethOracle =
      denominatedOracleFactory.deployDenominatedOracle(_rethETHOracle, chainlinkEthUSDPriceFeed, false);

    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_arbUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(chainlinkEthUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[CBETH] = delayedOracleFactory.deployDelayedOracle(chainlinkEthUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_rethOracle, ORACLE_INTERVAL_TEST);

    // Setup collateral types
    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);
  }

  /**
   * @dev postdeployment moved to od-relayer
   */
  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeployAnvil is SepoliaParams, Deploy {
  function setUp() public virtual {
    if (!isNetworkAnvil()) {
      revert('DeployAnvil: network is not Anvil');
    }
    _deployerPk = uint256(vm.envBytes32('ANVIL_ONE'));
    chainId = 31_337;
  }

  // Setup oracle feeds
  function setupEnvironment() public virtual override updateParams {
    // OD
    systemCoinOracle = new OracleForTestnet(OD_INITIAL_PRICE); // 1 OD = 1 USD 'OD / USD'

    // Test tokens
    collateral[ARB] = new MintableVoteERC20('Arbitrum', 'ARB', 18);
    collateral[WSTETH] = new MintableERC20('Wrapped liquid staked Ether 2.0', 'wstETH', 18);
    collateral[CBETH] = new MintableERC20('Coinbase Wrapped Staked ETH', 'cbETH', 18);
    collateral[RETH] = new MintableERC20('Rocket Pool ETH', 'rETH', 18);

    // WSTETH
    IBaseOracle _wstethUSDPriceFeed = new OracleForTestnet(1500e18);

    // ARB
    OracleForTestnet _arbETHPriceFeed = new OracleForTestnet(0.00055e18);
    IBaseOracle _arbOracle =
      denominatedOracleFactory.deployDenominatedOracle(_arbETHPriceFeed, _wstethUSDPriceFeed, false);

    // CBETH
    IBaseOracle _cbethETHPriceFeed = new OracleForTestnet(1e18);
    IBaseOracle _cbethOracle =
      denominatedOracleFactory.deployDenominatedOracle(_cbethETHPriceFeed, _wstethUSDPriceFeed, false);

    // RETH
    IBaseOracle _rethETHOracle = new OracleForTestnet(0.98e18);
    IBaseOracle _rethOracle =
      denominatedOracleFactory.deployDenominatedOracle(_rethETHOracle, _wstethUSDPriceFeed, false);

    delayedOracle[ARB] = delayedOracleFactory.deployDelayedOracle(_arbOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, ORACLE_INTERVAL_TEST);
    delayedOracle[CBETH] = delayedOracleFactory.deployDelayedOracle(_cbethOracle, ORACLE_INTERVAL_TEST);
    delayedOracle[RETH] = delayedOracleFactory.deployDelayedOracle(_rethOracle, ORACLE_INTERVAL_TEST);

    // Setup collateral types
    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}
