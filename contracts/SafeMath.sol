// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity 0.8.4;

// based on openzeppelin SafeMath library
library SafeMath {
    function subtract(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
}