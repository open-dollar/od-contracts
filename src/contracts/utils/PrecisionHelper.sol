// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract PrecisionHelper {

    function wadToRad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    function radToWad(uint256 rad) internal pure returns (uint256) {
        return rad / 10 ** 27;
    }

}