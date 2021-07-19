// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity ^0.8.4;

contract UniqueKeyGenerator {
    uint256 private salt;

    function generateKey(address a) public view returns (bytes32) {
        return keccak256(abi.encode(uint256(uint160(a)) + salt));
    }

    function changeKeySalt() internal {
        salt++;
    }
}