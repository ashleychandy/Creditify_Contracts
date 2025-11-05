// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPoolAddressesProviderRegistry {
  
  event AddressesProviderRegistered(address indexed addressesProvider, uint256 indexed id);

  event AddressesProviderUnregistered(address indexed addressesProvider, uint256 indexed id);

  function getAddressesProvidersList() external view returns (address[] memory);

  function getAddressesProviderIdByAddress(
    address addressesProvider
  ) external view returns (uint256);

  function getAddressesProviderAddressById(uint256 id) external view returns (address);

  function registerAddressesProvider(address provider, uint256 id) external;

  function unregisterAddressesProvider(address provider) external;
}
