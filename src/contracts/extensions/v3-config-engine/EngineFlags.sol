// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library EngineFlags {
    uint256 internal constant KEEP_CURRENT = type(uint256).max - 42;

    string internal constant KEEP_CURRENT_STRING = "KEEP_CURRENT_STRING";

    address internal constant KEEP_CURRENT_ADDRESS = address(0x0000000000000000000000000000000000000050);

    uint256 internal constant ENABLED = 1;

    uint256 internal constant DISABLED = 0;

    function toBool(uint256 flag) internal pure returns (bool) {
        require(flag == 0 || flag == 1, "INVALID_CONVERSION_TO_BOOL");
        return flag == 1;
    }

    function fromBool(bool isTrue) internal pure returns (uint256) {
        return isTrue ? ENABLED : DISABLED;
    }
}
