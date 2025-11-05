// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {IPool, IPoolAddressesProvider} from '../../../interfaces/IPool.sol';

interface IStataTokenFactory {
  event StataTokenCreated(address indexed stataToken, address indexed underlying);

  error NotListedUnderlying(address underlying);

  function POOL() external view returns (IPool);

  function INITIAL_OWNER() external view returns (address);

  function TRANSPARENT_PROXY_FACTORY() external view returns (ITransparentProxyFactory);

  function STATA_TOKEN_IMPL() external view returns (address);

  function createStataTokens(address[] memory underlyings) external returns (address[] memory);

  function getStataTokens() external view returns (address[] memory);

  function getStataToken(address underlying) external view returns (address);
}
