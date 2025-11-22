// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pool} from "../protocol/pool/Pool.sol";
import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {IReserveInterestRateStrategy} from "../interfaces/IReserveInterestRateStrategy.sol";
import {Errors} from "../protocol/libraries/helpers/Errors.sol";

contract PoolInstance is Pool {
    uint256 public constant POOL_REVISION = 9;

    constructor(IPoolAddressesProvider provider, IReserveInterestRateStrategy interestRateStrategy_)
        Pool(provider, interestRateStrategy_)
    {}

    function initialize(IPoolAddressesProvider provider) external virtual override initializer {
        require(provider == ADDRESSES_PROVIDER, Errors.InvalidAddressesProvider());
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return POOL_REVISION;
    }
}
