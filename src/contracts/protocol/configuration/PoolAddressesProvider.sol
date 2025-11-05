// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '../../dependencies/openzeppelin/contracts/Ownable.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {InitializableImmutableAdminUpgradeabilityProxy} from '../../misc/creditify-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol';

contract PoolAddressesProvider is Ownable, IPoolAddressesProvider {
  
  string private _marketId;

  mapping(bytes32 => address) private _addresses;

  bytes32 private constant POOL = 'POOL';
  bytes32 private constant POOL_CONFIGURATOR = 'POOL_CONFIGURATOR';
  bytes32 private constant PRICE_ORACLE = 'PRICE_ORACLE';
  bytes32 private constant ACL_MANAGER = 'ACL_MANAGER';
  bytes32 private constant ACL_ADMIN = 'ACL_ADMIN';
  bytes32 private constant PRICE_ORACLE_SENTINEL = 'PRICE_ORACLE_SENTINEL';
  bytes32 private constant DATA_PROVIDER = 'DATA_PROVIDER';

  constructor(string memory marketId, address owner) {
    _setMarketId(marketId);
    transferOwnership(owner);
  }

  function getMarketId() external view override returns (string memory) {
    return _marketId;
  }

  function setMarketId(string memory newMarketId) external override onlyOwner {
    _setMarketId(newMarketId);
  }

  function getAddress(bytes32 id) public view override returns (address) {
    return _addresses[id];
  }

  function setAddress(bytes32 id, address newAddress) external override onlyOwner {
    address oldAddress = _addresses[id];
    _addresses[id] = newAddress;
    emit AddressSet(id, oldAddress, newAddress);
  }

  function setAddressAsProxy(
    bytes32 id,
    address newImplementationAddress
  ) external override onlyOwner {
    address proxyAddress = _addresses[id];
    address oldImplementationAddress = _getProxyImplementation(id);
    _updateImpl(id, newImplementationAddress);
    emit AddressSetAsProxy(id, proxyAddress, oldImplementationAddress, newImplementationAddress);
  }

  function getPool() external view override returns (address) {
    return getAddress(POOL);
  }

  function setPoolImpl(address newPoolImpl) external override onlyOwner {
    address oldPoolImpl = _getProxyImplementation(POOL);
    _updateImpl(POOL, newPoolImpl);
    emit PoolUpdated(oldPoolImpl, newPoolImpl);
  }

  function getPoolConfigurator() external view override returns (address) {
    return getAddress(POOL_CONFIGURATOR);
  }

  function setPoolConfiguratorImpl(address newPoolConfiguratorImpl) external override onlyOwner {
    address oldPoolConfiguratorImpl = _getProxyImplementation(POOL_CONFIGURATOR);
    _updateImpl(POOL_CONFIGURATOR, newPoolConfiguratorImpl);
    emit PoolConfiguratorUpdated(oldPoolConfiguratorImpl, newPoolConfiguratorImpl);
  }

  function getPriceOracle() external view override returns (address) {
    return getAddress(PRICE_ORACLE);
  }

  function setPriceOracle(address newPriceOracle) external override onlyOwner {
    address oldPriceOracle = _addresses[PRICE_ORACLE];
    _addresses[PRICE_ORACLE] = newPriceOracle;
    emit PriceOracleUpdated(oldPriceOracle, newPriceOracle);
  }

  function getACLManager() external view override returns (address) {
    return getAddress(ACL_MANAGER);
  }

  function setACLManager(address newAclManager) external override onlyOwner {
    address oldAclManager = _addresses[ACL_MANAGER];
    _addresses[ACL_MANAGER] = newAclManager;
    emit ACLManagerUpdated(oldAclManager, newAclManager);
  }

  function getACLAdmin() external view override returns (address) {
    return getAddress(ACL_ADMIN);
  }

  function setACLAdmin(address newAclAdmin) external override onlyOwner {
    address oldAclAdmin = _addresses[ACL_ADMIN];
    _addresses[ACL_ADMIN] = newAclAdmin;
    emit ACLAdminUpdated(oldAclAdmin, newAclAdmin);
  }

  function getPoolDataProvider() external view override returns (address) {
    return getAddress(DATA_PROVIDER);
  }

  function setPoolDataProvider(address newDataProvider) external override onlyOwner {
    address oldDataProvider = _addresses[DATA_PROVIDER];
    _addresses[DATA_PROVIDER] = newDataProvider;
    emit PoolDataProviderUpdated(oldDataProvider, newDataProvider);
  }

  function _updateImpl(bytes32 id, address newAddress) internal {
    address proxyAddress = _addresses[id];
    InitializableImmutableAdminUpgradeabilityProxy proxy;
    bytes memory params = abi.encodeWithSignature('initialize(address)', address(this));

    if (proxyAddress == address(0)) {
      proxy = new InitializableImmutableAdminUpgradeabilityProxy(address(this));
      _addresses[id] = proxyAddress = address(proxy);
      proxy.initialize(newAddress, params);
      emit ProxyCreated(id, proxyAddress, newAddress);
    } else {
      proxy = InitializableImmutableAdminUpgradeabilityProxy(payable(proxyAddress));
      proxy.upgradeToAndCall(newAddress, params);
    }
  }

  function _setMarketId(string memory newMarketId) internal {
    string memory oldMarketId = _marketId;
    _marketId = newMarketId;
    emit MarketIdSet(oldMarketId, newMarketId);
  }

  function _getProxyImplementation(bytes32 id) internal returns (address) {
    address proxyAddress = _addresses[id];
    if (proxyAddress == address(0)) {
      return address(0);
    } else {
      address payable payableProxyAddress = payable(proxyAddress);
      return InitializableImmutableAdminUpgradeabilityProxy(payableProxyAddress).implementation();
    }
  }
}
