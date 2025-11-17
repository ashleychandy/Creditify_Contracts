// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '../../dependencies/openzeppelin/contracts/Ownable.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {IPoolAddressesProviderRegistry} from '../../interfaces/IPoolAddressesProviderRegistry.sol';

contract PoolAddressesProviderRegistry is Ownable, IPoolAddressesProviderRegistry {
  mapping(address => uint256) private _addressesProviderToId;

  mapping(uint256 => address) private _idToAddressesProvider;

  address[] private _addressesProvidersList;

  mapping(address => uint256) private _addressesProvidersIndexes;

  constructor(address owner) {
    transferOwnership(owner);
  }

  function getAddressesProvidersList() external view override returns (address[] memory) {
    return _addressesProvidersList;
  }

  function registerAddressesProvider(address provider, uint256 id) external override onlyOwner {
    require(
      id != 0 && _idToAddressesProvider[id] == address(0),
      Errors.InvalidAddressesProviderId()
    );
    require(_addressesProviderToId[provider] == 0, Errors.AddressesProviderAlreadyAdded());

    _addressesProviderToId[provider] = id;
    _idToAddressesProvider[id] = provider;

    _addToAddressesProvidersList(provider);
    emit AddressesProviderRegistered(provider, id);
  }

  function unregisterAddressesProvider(address provider) external override onlyOwner {
    require(_addressesProviderToId[provider] != 0, Errors.AddressesProviderNotRegistered());
    uint256 oldId = _addressesProviderToId[provider];
    _idToAddressesProvider[oldId] = address(0);
    _addressesProviderToId[provider] = 0;

    _removeFromAddressesProvidersList(provider);

    emit AddressesProviderUnregistered(provider, oldId);
  }

  function getAddressesProviderIdByAddress(
    address addressesProvider
  ) external view override returns (uint256) {
    return _addressesProviderToId[addressesProvider];
  }

  function getAddressesProviderAddressById(uint256 id) external view override returns (address) {
    return _idToAddressesProvider[id];
  }

  function _addToAddressesProvidersList(address provider) internal {
    _addressesProvidersIndexes[provider] = _addressesProvidersList.length;
    _addressesProvidersList.push(provider);
  }

  function _removeFromAddressesProvidersList(address provider) internal {
    uint256 index = _addressesProvidersIndexes[provider];

    _addressesProvidersIndexes[provider] = 0;

    uint256 lastIndex = _addressesProvidersList.length - 1;
    if (index < lastIndex) {
      address lastProvider = _addressesProvidersList[lastIndex];
      _addressesProvidersList[index] = lastProvider;
      _addressesProvidersIndexes[lastProvider] = index;
    }
    _addressesProvidersList.pop();
  }
}
