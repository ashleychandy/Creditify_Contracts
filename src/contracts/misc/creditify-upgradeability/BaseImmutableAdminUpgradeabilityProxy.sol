// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseUpgradeabilityProxy} from '../../dependencies/openzeppelin/upgradeability/BaseUpgradeabilityProxy.sol';

contract BaseImmutableAdminUpgradeabilityProxy is BaseUpgradeabilityProxy {
  address internal immutable _admin;

  constructor(address admin_) {
    _admin = admin_;
  }

  modifier ifAdmin() {
    if (msg.sender == _admin) {
      _;
    } else {
      _fallback();
    }
  }

  function admin() external ifAdmin returns (address) {
    return _admin;
  }

  function implementation() external ifAdmin returns (address) {
    return _implementation();
  }

  function upgradeTo(address newImplementation) external ifAdmin {
    _upgradeTo(newImplementation);
  }

  function upgradeToAndCall(
    address newImplementation,
    bytes calldata data
  ) external payable ifAdmin {
    _upgradeTo(newImplementation);
    (bool success, ) = newImplementation.delegatecall(data);
    require(success);
  }

  function _willFallback() internal virtual override {
    require(msg.sender != _admin, 'Cannot call fallback function from the proxy admin');
    super._willFallback();
  }
}
