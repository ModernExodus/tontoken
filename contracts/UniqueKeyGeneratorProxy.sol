// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity ^0.8.4;

import "./UniqueKeyGenerator.sol";

// proxy to interact with UniqueKeyGenerator for unit testing
contract UniqueKeyGeneratorProxy is UniqueKeyGenerator {
    function changeSalt() public {
        super.changeKeySalt();
    }
}