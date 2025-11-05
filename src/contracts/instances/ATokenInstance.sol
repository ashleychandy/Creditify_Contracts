// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from '../interfaces/IPool.sol';
import {IInitializableAToken} from '../interfaces/IInitializableAToken.sol';

import {Errors} from '../protocol/libraries/helpers/Errors.sol';

import {VersionedInitializable} from '../misc/creditify-upgradeability/VersionedInitializable.sol';

import {AToken} from '../protocol/tokenization/AToken.sol';

contract ATokenInstance is AToken {
  uint256 public constant ATOKEN_REVISION = 4;

  constructor(
    IPool pool,
    address rewardsController,
    address treasury
  ) AToken(pool, rewardsController, treasury) {}

  function getRevision() internal pure virtual override returns (uint256) {
    return ATOKEN_REVISION;
  }

  function initialize(
    IPool initializingPool,
    address underlyingAsset,
    uint8 aTokenDecimals,
    string calldata aTokenName,
    string calldata aTokenSymbol,
    bytes calldata params
  ) public virtual override initializer {
    require(initializingPool == POOL, Errors.PoolAddressesDoNotMatch());
    _setName(aTokenName);
    _setSymbol(aTokenSymbol);
    _setDecimals(aTokenDecimals);

    _underlyingAsset = underlyingAsset;

    _domainSeparator = _calculateDomainSeparator();

    emit Initialized(
      underlyingAsset,
      address(POOL),
      address(TREASURY),
      address(REWARDS_CONTROLLER),
      aTokenDecimals,
      aTokenName,
      aTokenSymbol,
      params
    );
  }
}
