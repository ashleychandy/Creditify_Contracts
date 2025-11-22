// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolInstance} from "../../../contracts/instances/PoolInstance.sol";
import {IPoolAddressesProvider} from "../../../contracts/interfaces/IPoolAddressesProvider.sol";
import {IReserveInterestRateStrategy} from "../../../contracts/interfaces/IReserveInterestRateStrategy.sol";
import {IPool} from "../../../contracts/interfaces/IPool.sol";
import {CreditifyV3PoolConfigProcedure} from "./CreditifyV3PoolConfigProcedure.sol";
import {IErrors} from "../../interfaces/IErrors.sol";
import "../../interfaces/IMarketReportTypes.sol";

contract CreditifyV3PoolProcedure is CreditifyV3PoolConfigProcedure, IErrors {
    function _deployCreditifyV3Pool(address poolAddressesProvider, address interestRateStrategy)
        internal
        returns (PoolReport memory)
    {
        if (poolAddressesProvider == address(0)) revert ProviderNotFound();
        if (interestRateStrategy == address(0)) revert InterestRateStrategyNotFound();

        PoolReport memory report;

        report.poolImplementation = _deployPoolImpl(poolAddressesProvider, interestRateStrategy);
        report.poolConfiguratorImplementation = _deployPoolConfigurator();

        return report;
    }

    function _deployPoolImpl(address poolAddressesProvider, address interestRateStrategy) internal returns (address) {
        address pool = address(
            new PoolInstance(
                IPoolAddressesProvider(poolAddressesProvider), IReserveInterestRateStrategy(interestRateStrategy)
            )
        );

        return pool;
    }
}
