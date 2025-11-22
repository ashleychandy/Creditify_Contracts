// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolConfiguratorInstance} from "../../../contracts/instances/PoolConfiguratorInstance.sol";
import {IPoolAddressesProvider} from "../../../contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../../../contracts/interfaces/IPool.sol";
import {CreditifyOracle} from "../../../contracts/misc/CreditifyOracle.sol";

contract CreditifyV3PoolConfigProcedure {
    function _deployPoolConfigurator() internal returns (address) {
        PoolConfiguratorInstance poolConfiguratorImplementation = new PoolConfiguratorInstance();

        return address(poolConfiguratorImplementation);
    }
}
