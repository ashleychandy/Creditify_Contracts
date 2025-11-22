// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {InitializableUpgradeabilityProxy} from
    "../../dependencies/openzeppelin/upgradeability/InitializableUpgradeabilityProxy.sol";
import {Proxy} from "../../dependencies/openzeppelin/upgradeability/Proxy.sol";
import {BaseImmutableAdminUpgradeabilityProxy} from "./BaseImmutableAdminUpgradeabilityProxy.sol";

contract InitializableImmutableAdminUpgradeabilityProxy is
    BaseImmutableAdminUpgradeabilityProxy,
    InitializableUpgradeabilityProxy
{
    constructor(address admin) BaseImmutableAdminUpgradeabilityProxy(admin) {}

    function _willFallback() internal override(BaseImmutableAdminUpgradeabilityProxy, Proxy) {
        BaseImmutableAdminUpgradeabilityProxy._willFallback();
    }
}
