// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {DateTime} from '@libraries/DateTime.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import {Base64} from '@openzeppelin/utils/Base64.sol';
import {Math} from '@libraries/Math.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

contract NFTRenderer {
  using Strings for uint256;
  using Math for uint256;
  using DateTime for uint256;

  uint256 internal constant _RAY = 1e27;

  IVault721 public immutable vault721;

  // protocol contracts
  IODSafeManager internal _safeManager;
  ISAFEEngine internal _safeEngine;
  IOracleRelayer internal _oracleRelayer;
  ITaxCollector internal _taxCollector;
  ICollateralJoinFactory internal _collateralJoinFactory;

  event ImplementationSet(
    address safeManager, address safeEngine, address oracleRelayer, address taxCollector, address collateralJoinFactory
  );

  constructor(address _vault721, address oracleRelayer, address taxCollector, address collateralJoinFactory) {
    vault721 = IVault721(_vault721);
    vault721.initializeRenderer();
    _safeManager = IODSafeManager(vault721.safeManager());
    _safeEngine = ISAFEEngine(_safeManager.safeEngine());
    _oracleRelayer = IOracleRelayer(oracleRelayer);
    _taxCollector = ITaxCollector(taxCollector);
    _collateralJoinFactory = ICollateralJoinFactory(collateralJoinFactory);
  }

  // state = {0: (no collateral, no debt) 1: (collateral, no debt) 2: (collateral, debt)}
  struct VaultParams {
    uint256 state;
    uint256 ratio;
    string collateralJson;
    string debtJson;
    string collateralSvg;
    string debtSvg;
    string vaultId;
    string stabilityFee;
    string symbol;
    string risk;
    string color;
    string stroke;
    string lastUpdate;
    string lastBlockNumber;
    string lastBlockTimestamp;
    string tokenCollateral;
  }

  /**
   * @dev upgradeability permissioned to governor via Vault721
   */
  function setImplementation(
    address safeManager,
    address oracleRelayer,
    address taxCollector,
    address collateralJoinFactory
  ) external {
    require(msg.sender == address(vault721), 'NFT: only vault721');
    _safeManager = IODSafeManager(safeManager);
    _safeEngine = ISAFEEngine(_safeManager.safeEngine());
    _oracleRelayer = IOracleRelayer(oracleRelayer);
    _taxCollector = ITaxCollector(taxCollector);
    _collateralJoinFactory = ICollateralJoinFactory(collateralJoinFactory);

    emit ImplementationSet(
      address(_safeManager),
      address(_safeEngine),
      address(_oracleRelayer),
      address(_taxCollector),
      address(_collateralJoinFactory)
    );
  }

  /**
   * @dev render json object with NFT description and image
   * @notice svg needs to be broken into separate functions to reduce call stack for compilation
   */
  function render(uint256 _safeId) external view returns (string memory _uri) {
    VaultParams memory params = renderParams(_safeId);
    string memory text = _renderText(params);
    uint256 ratio = params.ratio;

    string memory json = string.concat(
      '{"name":"OD NFV #',
      text,
      '"}],"image":"data:image/svg+xml;base64,',
      Base64.encode(
        bytes(
          string.concat(
            _renderVaultInfo(params.vaultId, params.color),
            _renderCollatAndDebt(
              ratio, params.stabilityFee, params.debtSvg, params.collateralSvg, params.symbol, params.lastUpdate
            ),
            _renderRisk(params.state, ratio, params.stroke, params.risk),
            _renderBackground(params.color)
          )
        )
      ),
      '"}'
    );
    _uri = string.concat('data:application/json;base64,', Base64.encode(bytes(json)));
  }

  /**
   * @dev reads from various protocol contracts to collect data about user vaults by vault id
   */
  function renderParams(uint256 _safeId) public view returns (VaultParams memory) {
    VaultParams memory params;
    params.vaultId = _safeId.toString();

    bytes32 cType;
    // scoped to reduce call stack
    {
      IVault721.NFVState memory nfvState = vault721.getNfvState(_safeId);
      cType = nfvState.cType;
      address safeHandler = nfvState.safeHandler;
      params.lastBlockNumber = nfvState.lastBlockNumber.toString();
      params.lastBlockTimestamp = nfvState.lastBlockTimestamp.toString();

      (uint256 collateral, uint256 debt) = _renderValue(cType, safeHandler);
      params.collateralJson = collateral.toString();
      params.collateralSvg = _formatNumberForSvg(collateral);
      params.debtJson = debt.toString();
      params.debtSvg = _formatNumberForSvg(debt);

      params.tokenCollateral = _formatNumberForJson(_safeEngine.tokenCollateral(cType, safeHandler));

      IOracleRelayer.OracleRelayerCollateralParams memory oracleParams = _oracleRelayer.cParams(cType);
      IDelayedOracle oracle = oracleParams.oracle;
      uint256 safetyCRatio = oracleParams.safetyCRatio / 10e24;
      uint256 liquidationCRatio = oracleParams.liquidationCRatio / 10e24;

      uint256 ratio;
      uint256 state;
      if (collateral > 0) {
        if (debt > 0) {
          state = 2;
          ISAFEEngine.SAFEEngineCollateralData memory cTypeData = _safeEngine.cData(cType);
          ratio = ((collateral.wmul(oracle.read())).wdiv(debt.wmul(cTypeData.accumulatedRate))) / 1e7; // _RAY to _WAD conversion
        } else {
          state = 1;
          ratio = 200;
        }
      }
      IERC20Metadata token = ICollateralJoin(_collateralJoinFactory.collateralJoins(cType)).collateral();
      params.symbol = token.symbol();

      params.lastUpdate = _formatDateTime(oracle.lastUpdateTime());
      (params.risk, params.color) = _calcRisk(ratio, state, liquidationCRatio, safetyCRatio);
      params.stroke = _calcStroke(ratio);
      params.ratio = ratio;
      params.state = state;
    }
    ITaxCollector.TaxCollectorCollateralData memory taxData = _taxCollector.cData(cType);
    params.stabilityFee = _formatNumberForSvgRay(taxData.nextStabilityFee);

    return params;
  }

  /**
   * @dev generated debt & locked collateral
   */
  function _renderValue(bytes32 _cType, address _safeHandler) internal view returns (uint256, uint256) {
    ISAFEEngine.SAFE memory SafeEngineData = ISAFEEngine(_safeManager.safeEngine()).safes(_cType, _safeHandler);
    return (SafeEngineData.lockedCollateral, SafeEngineData.generatedDebt);
  }

  /**
   * @dev json text
   */
  function _renderText(VaultParams memory params) internal pure returns (string memory text) {
    string memory desc = _renderDesc(params.vaultId);
    string memory traits = _renderTraits(params);
    text = string.concat(
      params.vaultId,
      '","description":',
      desc,
      '"attributes":[{"trait_type":"ID","value":"',
      params.vaultId,
      traits,
      params.lastUpdate,
      '"},{"trait_type":"Modified on Block","value":"',
      params.lastBlockNumber,
      '"},{"trait_type":"Modified at Timestamp ","value":"',
      params.lastBlockTimestamp,
      '"},{"trait_type":"Internal Collateral","value":"',
      params.tokenCollateral
    );
  }

  /**
   * @dev json description
   */
  function _renderDesc(string memory _safeId) internal pure returns (string memory desc) {
    desc = string.concat(
      '"Non-Fungible Vault #',
      _safeId,
      ' Caution! Trading this NFV gives the recipient full ownership of your Vault, including all collateral & debt obligations. This act is irreversible.",'
    );
  }

  /**
   * @dev json attributes
   */
  function _renderTraits(VaultParams memory params) internal pure returns (string memory traits) {
    // stack at 16 slot max w/ 32-byte+ strings
    traits = string.concat(
      '"},{"trait_type":"Debt","value":"',
      params.debtJson,
      '"},{"trait_type":"Collateral","value":"',
      params.collateralJson,
      '"},{"trait_type":"Collateral Type","value":"',
      params.symbol,
      '"},{"trait_type":"Stability Fee","value":"',
      params.stabilityFee,
      '"},{"trait_type":"Risk","value":"',
      params.risk,
      '"},{"trait_type":"Collateral Ratio","value":"',
      params.ratio.toString(),
      '"},{"trait_type":"Last Updated","value":"'
    );
  }

  /**
   * @dev svg vault/token id
   */
  function _renderVaultInfo(string memory vaultId, string memory color) internal pure returns (string memory svg) {
    svg = string.concat(
      '<svg width="420" height="420" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><a target="_blank" href="https://app.dev.opendollar.com/#/vaults/',
      vaultId,
      '"><style>.graph-bg { fill: none; stroke: #000; stroke-width: 20; opacity: 80%;} .graph {fill: none; stroke-width: 20; stroke-linecap: flat; animation: progress 1s ease-out forwards;} .chart {stroke: ',
      color,
      ';opacity: 40%;} .risk-ratio {fill: ',
      color,
      ';}@keyframes progress {0% {stroke-dasharray: 0 1005;}} @keyframes liquidation {0% {  opacity: 80%;} 50% {  opacity: 20%;} 100 {  opacity: 80%;}}</style><g font-family="Inter, Verdana, sans-serif" style="white-space:pre" font-size="12"><path fill="#001828" d="M0 0H420V420H0z" /><path fill="url(#gradient)" d="M0 0H420V420H0z" /><path id="od-pattern-tile" opacity=".05" d="M49.7-40a145 145 0 1 0 0 290m0-290V8.2m0-48.4a145 145 0 1 1 0 290m0-241.6a96.7 96.7 0 1 0 0 193.3m0-193.3a96.7 96.7 0 1 1 0 193.3m0 0v48.3m0-96.6a48.3 48.3 0 0 0 0-96.7v96.7Zm0 0a48.3 48.3 0 0 1 0-96.7v96.7Z" stroke="#fff" /><use xlink:href="#od-pattern-tile" x="290" /><use xlink:href="#od-pattern-tile" y="290" /><use xlink:href="#od-pattern-tile" x="290" y="290" /><use xlink:href="#od-pattern-tile" x="193" y="145" /><text fill="#00587E" xml:space="preserve"><tspan x="24" y="40.7">VAULT ID</tspan></text><text fill="#1499DA" xml:space="preserve" font-size="22"><tspan x="24" y="65">',
      vaultId,
      '</tspan></text><text fill="#00587E" xml:space="preserve"><tspan x="335.9" y="40.7">STABILITY</tspan><tspan x="335.9" y="54.7">FEE</tspan></text><text fill="#1499DA" xml:space="preserve" font-size="22"><tspan x="364" y="63.3">'
    );
  }

  /**
   * @dev svg collateral and debt data
   */
  function _renderCollatAndDebt(
    uint256 ratio,
    string memory stabilityFee,
    string memory debt,
    string memory collateral,
    string memory symbol,
    string memory lastUpdate
  ) internal pure returns (string memory svg) {
    string memory debtDetail;
    if (ratio != 0) {
      debtDetail = string.concat(
        '<text fill="#00587E" xml:space="preserve" font-weight="600"><tspan x="102" y="168.9">DEBT</tspan></text><text fill="#D0F1FF" xml:space="preserve" font-size="24"><tspan x="102" y="194">',
        debt,
        ' OD',
        '</tspan></text><text fill="#00587E" xml:space="preserve" font-weight="600"><tspan x="102" y="229.9">COLLATERAL</tspan></text><text fill="#D0F1FF" xml:space="preserve" font-size="24"><tspan x="102" y="255">',
        collateral,
        ' ',
        symbol,
        '</tspan></text><text opacity=".3" transform="rotate(-90 326.5 -58.5)" fill="#fff" xml:space="preserve" font-size="10"><tspan x="-10.3" y="7.3">Updated '
      );
    } else {
      debtDetail =
        '<text fill="#63676F" xml:space="preserve" font-size="24"><tspan x="136" y="210">Zero Balance</tspan></text><text opacity=".3" transform="rotate(-90 326.5 -58.5)" fill="#fff" xml:space="preserve" font-size="10"><tspan x="-10.3" y="7.3">Updated ';
    }
    svg = string.concat(
      stabilityFee,
      '%</tspan></text><text opacity=".3" transform="rotate(90 -66.5 101.5)" fill="#fff" xml:space="preserve" font-size="10"><tspan x=".5" y="7.3">opendollar.com</tspan></text>',
      debtDetail,
      lastUpdate
    );
  }

  /**
   * @dev svg risk data
   */
  function _renderRisk(
    uint256 state,
    uint256 ratio,
    string memory stroke,
    string memory risk
  ) internal pure returns (string memory svg) {
    string memory rectangle;
    string memory riskDetail;
    if (state == 2) {
      rectangle =
        '), 1005" d="M210 40a160 160 0 0 1 0 320 160 160 0 0 1 0-320" /></g><g class="risk-ratio"><rect x="242" y="306" width="154" height="82" rx="8" fill="#001828" fill-opacity=".7" /><circle cx="243" cy="326.5" r="4" /><text xml:space="preserve" font-weight="600"><tspan x="255" y="330.7">';
      riskDetail = string.concat(
        ' RISK</tspan></text><text xml:space="preserve"><tspan x="255" y="355.7">COLLATERAL</tspan><tspan x="255" y="371.7">RATIO ',
        ratio.toString(),
        '%</tspan></text>'
      );
    } else if (state == 1) {
      rectangle =
        '), 1005" d="M210 40a160 160 0 0 1 0 320 160 160 0 0 1 0-320" /></g><g class="risk-ratio"><rect x="242" y="306" width="154" height="82" rx="8" fill="#001828" fill-opacity=".7" /><circle cx="243" cy="326.5" r="4" /><text xml:space="preserve" font-weight="600"><tspan x="255" y="330.7">';
      riskDetail =
        ' RISK</tspan></text><text xml:space="preserve"><tspan x="255" y="355.7">COLLATERAL</tspan><tspan x="255" y="371.7">RATIO &#x221e;</tspan></text>';
    } else {
      rectangle =
        '), 1005" d="M210 40a160 160 0 0 1 0 320 160 160 0 0 1 0-320" /></g><g class="risk-ratio"><rect x="298" y="350" width="96" height="40" rx="8" fill="#001828" fill-opacity=".7" /><circle cx="299" cy="370.5" r="4" /><text xml:space="preserve" font-weight="600"><tspan x="311" y="374.7">';
      riskDetail = ' RISK</tspan></text>';
    }
    svg = string.concat(
      '</tspan></text><g opacity=".6"><text fill="#fff" xml:space="preserve"><tspan x="24" y="387.4">Powered by</tspan></text><path d="M112.5 388c-2 0-3-1.2-3-3.2v-3.3c0-2 1-3.3 3-3.3 2.1 0 3.2 1.3 3.2 3.3v3.3c0 2-1 3.3-3.2 3.3Zm-1.5-3.2c0 1.1.5 1.8 1.6 1.8 1 0 1.5-.7 1.5-1.8v-3.3c0-1.1-.4-1.8-1.5-1.8s-1.6.7-1.6 1.8v3.3ZM117.3 390.6l-.1-.2V381l.1-.2h1.2l.1.2v.7c.3-.7 1-1 1.8-1 1.3 0 2 1 2 2.6v2.3c0 1.6-.8 2.6-2 2.6-.8 0-1.4-.4-1.7-1v3.3c0 .1 0 .2-.2.2h-1.2Zm1.4-5.2c0 .9.5 1.3 1.1 1.3.7 0 1-.5 1-1.3v-2.2c0-.7-.3-1.3-1-1.3-.6 0-1.1.5-1.1 1.4v2ZM126.2 388c-1.6 0-2.6-1-2.6-2.6v-2.2c0-1.6 1-2.6 2.5-2.6 1.6 0 2.6 1 2.6 2.6v1.4c0 .1 0 .2-.2.2h-3.4v.6c0 1 .4 1.4 1.1 1.4.6 0 1-.3 1.1-.8l.2-.2 1 .3c.1 0 .2 0 .1.2-.2 1-1 1.8-2.4 1.8Zm-1.1-4.2h2.2v-.7c0-.8-.4-1.3-1.1-1.3-.8 0-1.1.5-1.1 1.3v.7ZM130.2 388l-.2-.2v-7l.2-.1h1.1c.1 0 .2 0 .2.2v.7c.4-.7 1-1 1.7-1 1.1 0 1.8.8 1.8 2.5v4.7l-.1.1h-1.2l-.2-.1V383c0-.8-.3-1.2-.8-1.2s-1 .4-1.2 1v4.9l-.1.1h-1.2ZM136.8 388l-.2-.2v-9.3c0-.1 0-.2.2-.2h2.6c2 0 3.1 1.3 3.1 3.3v3c0 2-1 3.3-3.1 3.3h-2.6Zm1.4-1.5h1.2c1 0 1.6-.7 1.6-1.8v-3c0-1.2-.5-1.9-1.6-1.9h-1.2v6.7ZM146.4 388c-1.6 0-2.6-1-2.6-2.6v-2.2c0-1.6 1-2.6 2.6-2.6 1.7 0 2.6 1 2.6 2.6v2.2c0 1.7-1 2.7-2.6 2.7Zm-1-2.6c0 .9.3 1.3 1 1.3.8 0 1.1-.4 1.1-1.3v-2.2c0-.8-.4-1.3-1-1.3-.8 0-1.1.5-1.1 1.3v2.2ZM150.6 388l-.2-.2V378l.2-.2h1.2l.2.2v9.7l-.2.1h-1.2ZM153.7 388l-.2-.2V378c0-.1 0-.2.2-.2h1.2l.1.2v9.7l-.1.1h-1.2ZM160 388l-.1-.2v-.8c-.4.7-1 1-1.7 1-1.1 0-1.9-.7-1.9-2 0-1.4.7-2.3 2.6-2.3h1v-.8c0-.7-.4-1-1-1s-.8.2-1 .8h-.2l-1-.2c-.1 0-.2-.1-.1-.2.2-1 1-1.7 2.4-1.7 1.5 0 2.3.7 2.3 2.2v5l-.2.1h-1Zm-2.3-2.2c0 .7.3 1 1 1 .5 0 1-.3 1.1-1v-1.1h-.8c-.8 0-1.3.4-1.3 1.1ZM163 388l-.2-.2v-7h1.5v1c.3-.7.9-1.2 1.8-1.2.1 0 .2 0 .2.2v1.1c0 .1 0 .2-.2.2-1 0-1.5.3-1.8 1v4.7l-.1.1H163Z" fill="#fff" /><path d="M97 383.2c0-2.7 2-4.8 4.7-4.8v1.6a3.2 3.2 0 0 0-3.1 3.2c0 1.8 1.4 3.2 3 3.2v1.6a4.7 4.7 0 0 1-4.6-4.8ZM101.7 384.8c.8 0 1.5-.7 1.5-1.6 0-.9-.7-1.6-1.5-1.6v3.2Z" fill="#fff" opacity=".5" /><path d="M106.3 383.2c0 2.7-2 4.8-4.6 4.8v-1.6c1.7 0 3-1.4 3-3.2 0-1.8-1.3-3.2-3-3.2v-1.6c2.6 0 4.6 2.1 4.6 4.8ZM101.7 381.6c-.9 0-1.6.7-1.6 1.6 0 .9.7 1.6 1.6 1.6v-3.2Z" fill="#fff" /></g><g class="chart"><path class="graph-bg" d="M210 40a160 160 0 0 1 0 320 160 160 0 0 1 0-320" /><path class="graph" stroke-dasharray="calc(10.05 * ',
      stroke,
      rectangle,
      risk,
      riskDetail
    );
  }

  /**
   * @dev svg background
   */
  function _renderBackground(string memory color) internal pure returns (string memory svg) {
    svg = string.concat(
      '</g></g><defs><radialGradient id="gradient" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="rotate(-133.2 301 119) scale(368.295)"><stop stop-color="',
      color,
      '" /><stop offset="1" stop-color="',
      color,
      '" stop-opacity="0" /></radialGradient></defs></a></svg>'
    );
  }

  /**
   * @dev calculates liquidation risk
   */
  function _calcRisk(
    uint256 ratio,
    uint256 state,
    uint256 liquidationRatio,
    uint256 safetyRatio
  ) internal pure returns (string memory, string memory) {
    if (state == 2) {
      if (ratio <= liquidationRatio) return ('LIQUIDATION', '#E45200');
      else if (ratio > liquidationRatio && ratio <= safetyRatio) return ('HIGH', '#E45200');
      else if (ratio > safetyRatio && ratio <= (safetyRatio * 120 / 100)) return ('ELEVATED', '#FCBF3B');
      else return ('LOW', '#5DBA14');
    } else if (state == 1) {
      return ('LOW', '#5DBA14');
    } else {
      return ('NO', '#63676F');
    }
  }

  /**
   * @dev fills circular stroke by percentage of collateral over 100% up to 200%
   */
  function _calcStroke(uint256 ratio) internal pure returns (string memory) {
    if (ratio == 0) return '0';
    if (ratio <= 100 || ratio >= 200) return '100';
    else return (ratio - 100).toString();
  }

  function _formatNumberForJson(uint256 num) internal pure returns (string memory) {
    (uint256 left, uint256 right) = _floatingPoint(num);
    return _parseNumber(left, right);
  }

  function _formatNumberForSvg(uint256 num) internal pure returns (string memory) {
    (uint256 left, uint256 right) = _floatingPoint(num);
    return _parseNumberWithComma(left, right);
  }

  function _formatNumberForSvgRay(uint256 num) internal pure returns (string memory) {
    uint256 left = num / _RAY;
    uint256 expLeft = left * _RAY;
    uint256 expRight = num - expLeft;
    uint256 right = expRight / 1e25; // format to 2 decimal places
    return _parseNumber(left, right);
  }

  /**
   * @dev converts uint from wei fixed-point to ether floating-point format
   */
  function _floatingPoint(uint256 num) internal pure returns (uint256 left, uint256 right) {
    left = num / 1e18;
    uint256 expLeft = left * 1e18;
    uint256 expRight = num - expLeft;
    right = expRight / 1e14; // format to 4 decimal places
  }

  /**
   * @dev parses number
   */
  function _parseNumber(uint256 left, uint256 right) internal pure returns (string memory) {
    if (left > 0) {
      return string.concat(left.toString(), '.', right.toString());
    } else {
      return string.concat('0.', right.toString());
    }
  }

  /**
   * @dev parses comma-separated number
   */
  function _parseNumberWithComma(uint256 left, uint256 right) internal pure returns (string memory) {
    if (left > 0) {
      return string.concat(_commaFormat(left), '.', right.toString());
    } else {
      return string.concat('0.', right.toString());
    }
  }

  /**
   * @dev adds commas every 3 digits
   */
  function _commaFormat(uint256 source) internal pure returns (string memory) {
    string memory result = '';
    uint128 index;

    while (source > 0) {
      uint256 part = source % 10; // get each digit
      bool isSet = index != 0 && index % 3 == 0; // request set glue for every additional 3 digits

      result = _concatWithComma(result, part, isSet);
      source = source / 10;
      index += 1;
    }

    return result;
  }

  /**
   * @dev concats with comma
   */
  function _concatWithComma(string memory base, uint256 part, bool isSet) internal pure returns (string memory) {
    string memory stringified = part.toString();
    string memory glue = ',';

    if (!isSet) glue = '';
    return string(abi.encodePacked(stringified, glue, base));
  }

  /**
   * @dev converts timestamp to human readable date and time format
   */
  function _formatDateTime(uint256 timestamp) internal pure returns (string memory) {
    (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute,) = timestamp.timestampToDateTime();

    string memory _month;
    if (month == 1) _month = 'Jan';
    else if (month == 2) _month = 'Feb';
    else if (month == 3) _month = 'Mar';
    else if (month == 4) _month = 'Apr';
    else if (month == 5) _month = 'May';
    else if (month == 6) _month = 'Jun';
    else if (month == 7) _month = 'Jul';
    else if (month == 8) _month = 'Aug';
    else if (month == 9) _month = 'Sep';
    else if (month == 10) _month = 'Oct';
    else if (month == 11) _month = 'Nov';
    else _month = 'Dec';

    return string.concat(
      _month, ' ', day.toString(), ', ', year.toString(), ' ', _formatTime(hour), ':', _formatTime(minute), ' UTC'
    );
  }

  /**
   * @dev zero pads single digits
   */
  function _formatTime(uint256 time) internal pure returns (string memory) {
    if (time < 10) return string.concat('0', time.toString());
    else return time.toString();
  }
}
