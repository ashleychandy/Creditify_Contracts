// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "../../../interfaces/IPool.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveConfiguration} from "./ReserveConfiguration.sol";

library UserConfiguration {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    uint256 internal constant BORROWING_MASK = 0x5555555555555555555555555555555555555555555555555555555555555555;
    uint256 internal constant COLLATERAL_MASK = 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

    function setBorrowing(DataTypes.UserConfigurationMap storage self, uint256 reserveIndex, bool borrowing) internal {
        unchecked {
            require(reserveIndex < ReserveConfiguration.MAX_RESERVES_COUNT, Errors.InvalidReserveIndex());
            uint256 bit = 1 << (reserveIndex << 1);
            if (borrowing) {
                self.data |= bit;
            } else {
                self.data &= ~bit;
            }
        }
    }

    function setUsingAsCollateral(
        DataTypes.UserConfigurationMap storage self,
        uint256 reserveIndex,
        address asset,
        address user,
        bool usingAsCollateral
    ) internal {
        unchecked {
            require(reserveIndex < ReserveConfiguration.MAX_RESERVES_COUNT, Errors.InvalidReserveIndex());
            uint256 bit = 1 << ((reserveIndex << 1) + 1);
            if (usingAsCollateral) {
                self.data |= bit;
                emit IPool.ReserveUsedAsCollateralEnabled(asset, user);
            } else {
                self.data &= ~bit;
                emit IPool.ReserveUsedAsCollateralDisabled(asset, user);
            }
        }
    }

    function isUsingAsCollateralOrBorrowing(DataTypes.UserConfigurationMap memory self, uint256 reserveIndex)
        internal
        pure
        returns (bool)
    {
        unchecked {
            require(reserveIndex < ReserveConfiguration.MAX_RESERVES_COUNT, Errors.InvalidReserveIndex());
            return (self.data >> (reserveIndex << 1)) & 3 != 0;
        }
    }

    function isBorrowing(DataTypes.UserConfigurationMap memory self, uint256 reserveIndex)
        internal
        pure
        returns (bool)
    {
        unchecked {
            require(reserveIndex < ReserveConfiguration.MAX_RESERVES_COUNT, Errors.InvalidReserveIndex());
            return (self.data >> (reserveIndex << 1)) & 1 != 0;
        }
    }

    function isUsingAsCollateral(DataTypes.UserConfigurationMap memory self, uint256 reserveIndex)
        internal
        pure
        returns (bool)
    {
        unchecked {
            require(reserveIndex < ReserveConfiguration.MAX_RESERVES_COUNT, Errors.InvalidReserveIndex());
            return (self.data >> ((reserveIndex << 1) + 1)) & 1 != 0;
        }
    }

    function isUsingAsCollateralOne(DataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        uint256 collateralData = self.data & COLLATERAL_MASK;
        return collateralData != 0 && (collateralData & (collateralData - 1) == 0);
    }

    function isUsingAsCollateralAny(DataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        return self.data & COLLATERAL_MASK != 0;
    }

    function isBorrowingOne(DataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        uint256 borrowingData = self.data & BORROWING_MASK;
        return borrowingData != 0 && (borrowingData & (borrowingData - 1) == 0);
    }

    function isBorrowingAny(DataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        return self.data & BORROWING_MASK != 0;
    }

    function isEmpty(DataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        return self.data == 0;
    }

    function getNextFlags(uint256 data) internal pure returns (uint256, bool, bool) {
        bool isBorrowed = data & 1 == 1;
        bool isEnabledAsCollateral = data & 2 == 2;
        return (data >> 2, isBorrowed, isEnabledAsCollateral);
    }

    function _getFirstAssetIdByMask(DataTypes.UserConfigurationMap memory self, uint256 mask)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            uint256 bitmapData = self.data & mask;
            uint256 firstAssetPosition = bitmapData & ~(bitmapData - 1);
            uint256 id;

            while ((firstAssetPosition >>= 2) != 0) {
                id += 1;
            }
            return id;
        }
    }
}
