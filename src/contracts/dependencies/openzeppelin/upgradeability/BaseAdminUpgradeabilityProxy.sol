// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './UpgradeabilityProxy.sol';

contract BaseAdminUpgradeabilityProxy is BaseUpgradeabilityProxy {
  
  event AdminChanged(address previousAdmin, address newAdmin);

  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  modifier ifAdmin() {
    if (msg.sender == _admin()) {
      _;
    } else {
      _fallback();
    }
  }

  function admin() external ifAdmin returns (address) {
    return _admin();
  }

  function implementation() external ifAdmin returns (address) {
    return _implementation();
  }

  function changeAdmin(address newAdmin) external ifAdmin {
    require(newAdmin != address(0), 'Cannot change the admin of a proxy to the zero address');
    emit AdminChanged(_admin(), newAdmin);
    _setAdmin(newAdmin);
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

  function _admin() internal view returns (address adm) {
    bytes32 slot = ADMIN_SLOT;
    
    assembly {
      adm := sload(slot)
    }
  }

  function _setAdmin(address newAdmin) internal {
    bytes32 slot = ADMIN_SLOT;
    
    assembly {
      sstore(slot, newAdmin)
    }
  }

  function _willFallback() internal virtual override {
    require(msg.sender != _admin(), 'Cannot call fallback function from the proxy admin');
    super._willFallback();
  }
}
