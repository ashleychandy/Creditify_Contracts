// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EngineFlags} from "../EngineFlags.sol";
import {DataTypes} from "../../../protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "../../../protocol/libraries/configuration/ReserveConfiguration.sol";
import {ICreditifyV3ConfigEngine as IEngine, IPoolConfigurator, IPool} from "../ICreditifyV3ConfigEngine.sol";

library BorrowEngine {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function executeBorrowSide(IEngine.EngineConstants calldata engineConstants, IEngine.BorrowUpdate[] memory updates)
        external
    {
        require(updates.length != 0, "AT_LEAST_ONE_UPDATE_REQUIRED");

        _configBorrowSide(engineConstants.poolConfigurator, engineConstants.pool, updates);
    }

    function _configBorrowSide(IPoolConfigurator poolConfigurator, IPool pool, IEngine.BorrowUpdate[] memory updates)
        internal
    {
        for (uint256 i = 0; i < updates.length; i++) {
            if (updates[i].enabledToBorrow != EngineFlags.KEEP_CURRENT) {
                poolConfigurator.setReserveBorrowing(updates[i].asset, EngineFlags.toBool(updates[i].enabledToBorrow));
            } else {
                (,, bool borrowingEnabled,) = pool.getConfiguration(updates[i].asset).getFlags();
                updates[i].enabledToBorrow = EngineFlags.fromBool(borrowingEnabled);
            }

            require(
                (updates[i].reserveFactor > 0 && updates[i].reserveFactor <= 100_00)
                    || updates[i].reserveFactor == EngineFlags.KEEP_CURRENT,
                "INVALID_RESERVE_FACTOR"
            );

            if (updates[i].reserveFactor != EngineFlags.KEEP_CURRENT) {
                poolConfigurator.setReserveFactor(updates[i].asset, updates[i].reserveFactor);
            }
        }
    }
}
