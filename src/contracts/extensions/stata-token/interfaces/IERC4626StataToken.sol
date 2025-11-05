// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPool, IPoolAddressesProvider} from '../../../interfaces/IPool.sol';

interface IERC4626StataToken {
  struct SignatureParams {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  error PoolAddressMismatch(address pool);

  error StaticATokenInvalidZeroShares();

  error OnlyPauseGuardian(address caller);

  function POOL() external view returns (IPool);

  function POOL_ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  function redeemATokens(
    uint256 shares,
    address receiver,
    address owner
  ) external returns (uint256);

  function depositATokens(uint256 assets, address receiver) external returns (uint256);

  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    SignatureParams memory sig,
    bool depositToCreditify
  ) external returns (uint256);

  function aToken() external view returns (address);

  function latestAnswer() external view returns (int256);
}
