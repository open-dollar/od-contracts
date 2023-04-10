pragma solidity ^0.6.7;

import "ds-test/test.sol";

import {DummyPIDCalculator} from '../../calculator/DummyPIDCalculator.sol';
import {MockPIRateSetter} from "../utils/mock/MockPIRateSetter.sol";
import {MockSetterRelayer} from "../utils/mock/MockSetterRelayer.sol";
import "../utils/mock/MockOracleRelayer.sol";

contract Feed {
    bytes32 public price;
    bool public validPrice;
    uint public lastUpdateTime;
    constructor(uint256 price_, bool validPrice_) public {
        price = bytes32(price_);
        validPrice = validPrice_;
        lastUpdateTime = now;
    }
    function updateTokenPrice(uint256 price_) external {
        price = bytes32(price_);
        lastUpdateTime = now;
    }
    function getResultWithValidity() external view returns (uint256, bool) {
        return (uint(price), validPrice);
    }
}

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract DummyPIDCalculatorTest is DSTest {
    Hevm hevm;

    MockOracleRelayer oracleRelayer;
    MockPIRateSetter rateSetter;
    MockSetterRelayer setterRelayer;

    DummyPIDCalculator calculator;
    Feed orcl;

    uint256 integralPeriodSize                = 3600;
    uint256 baseUpdateCallerReward            = 10 ether;
    uint256 maxUpdateCallerReward             = 30 ether;
    uint256 perSecondCallerRewardIncrease     = 1000002763984612345119745925;
    uint8   integralGranularity               = 24;

    address self;

    uint constant internal TWENTY_SEVEN_DECIMAL_NUMBER = 10**27;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        oracleRelayer = new MockOracleRelayer();
        orcl = new Feed(1 ether, true);

        setterRelayer = new MockSetterRelayer(address(oracleRelayer));
        calculator = new DummyPIDCalculator();
        rateSetter = new MockPIRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));

        setterRelayer.modifyParameters("setter", address(rateSetter));

        self = address(this);
    }

    function test_correct_setup() public {
        hevm.warp(now + integralGranularity);
        rateSetter.updateRate(address(this));

        assertEq(oracleRelayer.redemptionRate(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);

        assertEq(calculator.computeRate(1,1,1), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(calculator.rt(1,1,1), 1);
        assertEq(calculator.pscl(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(calculator.tlv(), 1);
    }
}
