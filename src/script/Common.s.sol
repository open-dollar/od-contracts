// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {Params, ParamChecker, HAI, ETH_A} from '@script/Params.s.sol';
import '@script/Registry.s.sol';

abstract contract Common is Contracts, Params {
  uint256 internal _deployerPk = 69; // for tests
  uint256 internal _governorPK;

  function deployEthCollateralContracts() public {
    // deploy ETHJoin and CollateralAuctionHouse
    // NOTE: deploying ETHJoinForTest to make it work with current tests
    ethJoin = new ETHJoinForTest(address(safeEngine), ETH_A);

    if (address(collateralAuctionHouseFactory) != address(0)) {
      collateralAuctionHouse[ETH_A] = ICollateralAuctionHouse(
        collateralAuctionHouseFactory.deployCollateralAuctionHouse(ETH_A, _collateralAuctionHouseCParams[ETH_A])
      );
    } else {
      collateralAuctionHouse[ETH_A] = new CollateralAuctionHouse({
          _safeEngine: address(safeEngine), 
          __oracleRelayer: address(oracleRelayer),
          __liquidationEngine: address(liquidationEngine), 
          _cType: ETH_A,
          _cahParams: _collateralAuctionHouseSystemCoinParams,
          _cahCParams: _collateralAuctionHouseCParams[ETH_A]
          });
    }

    collateralJoin[ETH_A] = CollateralJoin(address(ethJoin));
    safeEngine.addAuthorization(address(ethJoin));
  }

  function deployCollateralContracts(bytes32 _cType) public {
    // deploy CollateralJoin and CollateralAuctionHouse
    if (address(collateralJoinFactory) != address(0)) {
      address _delegatee = delegatee[_cType];
      if (_delegatee == address(0)) {
        collateralJoin[_cType] = CollateralJoin(
          collateralJoinFactory.deployCollateralJoin({_cType: _cType, _collateral: address(collateral[_cType])})
        );
      } else {
        collateralJoin[_cType] = CollateralJoin(
          collateralJoinFactory.deployDelegatableCollateralJoin({
            _cType: _cType,
            _collateral: address(collateral[_cType]),
            _delegatee: _delegatee
          })
        );
      }
    } else {
      collateralJoin[_cType] = new CollateralJoin({
        _safeEngine: address(safeEngine), 
        _cType: _cType,
        _collateral: address(collateral[_cType])
        });
    }

    if (address(collateralAuctionHouseFactory) != address(0)) {
      collateralAuctionHouse[_cType] = ICollateralAuctionHouse(
        collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _collateralAuctionHouseCParams[_cType])
      );
    } else {
      collateralAuctionHouse[_cType] = new CollateralAuctionHouse({
          _safeEngine: address(safeEngine), 
          __oracleRelayer: address(oracleRelayer),
          __liquidationEngine: address(liquidationEngine), 
          _cType: _cType,
          _cahParams: _collateralAuctionHouseSystemCoinParams,
          _cahCParams: _collateralAuctionHouseCParams[_cType]
          });
    }
  }

  function revokeAllTo(address _governor) public {
    if (!_shouldRevoke()) return;

    // base contracts
    _revoke(safeEngine, _governor);
    _revoke(liquidationEngine, _governor);
    _revoke(accountingEngine, _governor);
    _revoke(oracleRelayer, _governor);

    // auction houses
    _revoke(surplusAuctionHouse, _governor);
    _revoke(debtAuctionHouse, _governor);

    // tax
    _revoke(taxCollector, _governor);
    _revoke(stabilityFeeTreasury, _governor);

    // tokens
    _revoke(systemCoin, _governor);
    _revoke(protocolToken, _governor);

    // pid controller
    _revoke(pidController, _governor);
    _revoke(pidRateSetter, _governor);

    // token adapters
    _revoke(coinJoin, _governor);

    if (address(ethJoin) != address(0)) {
      _revoke(ethJoin, _governor);
    }

    // factories or children
    if (address(collateralJoinFactory) != address(0)) {
      _revoke(collateralJoinFactory, _governor);
    } else {
      for (uint256 _i; _i < collateralTypes.length; _i++) {
        bytes32 _cType = collateralTypes[_i];
        _revoke(collateralJoin[_cType], _governor);
      }
    }

    if (address(collateralAuctionHouseFactory) != address(0)) {
      _revoke(collateralAuctionHouseFactory, _governor);
    } else {
      for (uint256 _i; _i < collateralTypes.length; _i++) {
        bytes32 _cType = collateralTypes[_i];
        _revoke(collateralAuctionHouse[_cType], _governor);
      }
    }

    // global settlement
    _revoke(globalSettlement, _governor);
  }

  function revokeTo(IAuthorizable _contract, address _target) public {
    if (!_shouldRevoke()) return;

    _revoke(_contract, _target);
  }

  function _revoke(IAuthorizable _contract, address _target) internal {
    _contract.addAuthorization(_target);
    _contract.removeAuthorization(deployer);
  }

  function delegateAllTo(address __delegate) public {
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
    _delegate(protocolToken, __delegate);

    // pid controller
    _delegate(pidController, __delegate);
    _delegate(pidRateSetter, __delegate);

    // token adapters
    _delegate(coinJoin, __delegate);

    if (address(collateralJoinFactory) != address(0)) {
      _delegate(collateralJoinFactory, __delegate);
    } else {
      for (uint256 _i; _i < collateralTypes.length; _i++) {
        bytes32 _cType = collateralTypes[_i];
        _delegate(collateralJoin[_cType], __delegate);
      }
    }

    if (address(ethJoin) != address(0)) {
      _delegate(ethJoin, __delegate);
    }

    // global settlement
    _delegate(globalSettlement, __delegate);
  }

  function _delegate(IAuthorizable _contract, address _target) internal {
    _contract.addAuthorization(_target);
  }

  function deployContracts() public {
    // deploy Tokens
    systemCoin = new SystemCoin('HAI Index Token', 'HAI');
    protocolToken = new ProtocolToken('Protocol Token', 'KITE');

    // deploy Base contracts
    safeEngine = new SAFEEngine(_safeEngineParams);

    oracleRelayer = new OracleRelayer(address(safeEngine), systemCoinOracle, _oracleRelayerParams);

    surplusAuctionHouse =
      new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _surplusAuctionHouseParams);
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);

    accountingEngine =
    new AccountingEngine(address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse), _accountingEngineParams);

    liquidationEngine = new LiquidationEngine(address(safeEngine), address(accountingEngine), _liquidationEngineParams);

    collateralAuctionHouseFactory =
    new CollateralAuctionHouseFactory(address(safeEngine), address(oracleRelayer), address(liquidationEngine), _collateralAuctionHouseSystemCoinParams);

    // deploy Token adapters
    coinJoin = new CoinJoin(address(safeEngine), address(systemCoin));
    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));

    // TODO: deploy in separate module
    _getEnvironmentParams();
    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);

    stabilityFeeTreasury = new StabilityFeeTreasury(
          address(safeEngine),
          address(accountingEngine),
          address(coinJoin),
          _stabilityFeeTreasuryParams
        );

    _deployGlobalSettlement();
    _deployProxyContracts(address(safeEngine));
    _deployProxyActions();
  }

  // TODO: deploy PostSettlementSurplusAuctionHouse & SettlementSurplusAuctioneer
  function _deployGlobalSettlement() internal {
    globalSettlement = new GlobalSettlement();

    // setup globalSettlement [auth: disableContract]
    globalSettlement.modifyParameters('safeEngine', abi.encode(safeEngine));
    safeEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('liquidationEngine', abi.encode(liquidationEngine));
    liquidationEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('stabilityFeeTreasury', abi.encode(stabilityFeeTreasury));
    stabilityFeeTreasury.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('accountingEngine', abi.encode(accountingEngine));
    accountingEngine.addAuthorization(address(globalSettlement));
    globalSettlement.modifyParameters('oracleRelayer', abi.encode(oracleRelayer));
    oracleRelayer.addAuthorization(address(globalSettlement));

    collateralAuctionHouseFactory.addAuthorization(address(globalSettlement));
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
    safeEngine.initializeCollateralType(_cType, _safeEngineCParams[_cType]);
    oracleRelayer.initializeCollateralType(_cType, _oracleRelayerCParams[_cType]);
    liquidationEngine.initializeCollateralType(_cType, _liquidationEngineCParams[_cType]);

    taxCollector.initializeCollateralType(_cType, _taxCollectorCParams[_cType]);
    if (_taxCollectorSecondaryTaxReceiver.receiver != address(0)) {
      taxCollector.modifyParameters(_cType, 'secondaryTaxReceiver', abi.encode(_taxCollectorSecondaryTaxReceiver));
    }

    // setup initial price
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function deployPIDController() public {
    pidController = new PIDController({
      _cGains: _pidControllerGains,
      _pidParams: _pidControllerParams,
      _importedState: IPIDController.DeviationObservation(0,0,0)
    });

    pidRateSetter = new PIDRateSetter({
     _oracleRelayer: address(oracleRelayer),
     _pidCalculator: address(pidController),
     _updateRateDelay: _pidRateSetterParams.updateRateDelay
    });

    // setup registry
    pidController.modifyParameters('seedProposer', abi.encode(pidRateSetter));

    // auth
    oracleRelayer.addAuthorization(address(pidRateSetter));

    // initialize
    pidRateSetter.updateRate();
  }

  function _deployProxyContracts(address _safeEngine) internal {
    dsProxyFactory = new HaiProxyFactory();
    proxyRegistry = new HaiProxyRegistry(address(dsProxyFactory));
    safeManager = new HaiSafeManager(_safeEngine);
  }

  function _deployProxyActions() internal {
    proxyActions = new BasicActions();
    debtBidActions = new DebtBidActions();
    surplusActions = new SurplusBidActions();
    collateralActions = new CollateralBidActions();
  }

  function _shouldRevoke() internal view returns (bool) {
    return governor != deployer && governor != address(0);
  }
}
