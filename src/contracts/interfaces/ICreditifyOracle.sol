// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPriceOracleGetter} from './IPriceOracleGetter.sol';
import {IPoolAddressesProvider} from './IPoolAddressesProvider.sol';

interface ICreditifyOracle is IPriceOracleGetter {
  
  event BaseCurrencySet(address indexed baseCurrency, uint256 baseCurrencyUnit);

  event AssetSourceUpdated(address indexed asset, address indexed source);

  event FallbackOracleUpdated(address indexed fallbackOracle);

  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  function setAssetSources(address[] calldata assets, address[] calldata sources) external;

  function setFallbackOracle(address fallbackOracle) external;

  function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);

  function getSourceOfAsset(address asset) external view returns (address);

  function getFallbackOracle() external view returns (address);
}
