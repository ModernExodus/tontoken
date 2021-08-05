// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./UniqueKeyGenerator.sol";

// proxy to interact with UniqueKeyGenerator for unit testing
contract UniqueKeyGeneratorProxy is UniqueKeyGenerator {

    function generateKeyP(address a) public view returns (bytes32) {
        return super.generateKey(a);
    }

    function generateKeyP(uint256 u) public view returns (bytes32) {
        return super.generateKey(u);
    }

    function changeSalt() public {
        super.addSalt();
    }
}