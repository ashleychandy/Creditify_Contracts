// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./BaseAdminUpgradeabilityProxy.sol";
import "./InitializableUpgradeabilityProxy.sol";

contract InitializableAdminUpgradeabilityProxy is BaseAdminUpgradeabilityProxy, InitializableUpgradeabilityProxy {
    function initialize(address logic, address admin, bytes memory data) public payable {
        require(_implementation() == address(0));
        InitializableUpgradeabilityProxy.initialize(logic, data);
        assert(ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        _setAdmin(admin);
    }

    function _willFallback() internal override(BaseAdminUpgradeabilityProxy, Proxy) {
        BaseAdminUpgradeabilityProxy._willFallback();
    }
}
