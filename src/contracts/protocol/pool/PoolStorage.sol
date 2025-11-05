// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {UserConfiguration} from '../libraries/configuration/UserConfiguration.sol';
import {ReserveConfiguration} from '../libraries/configuration/ReserveConfiguration.sol';
import {ReserveLogic} from '../libraries/logic/ReserveLogic.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

contract PoolStorage {
  using ReserveLogic for DataTypes.ReserveData;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  mapping(address => DataTypes.ReserveData) internal _reserves;

  mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

  mapping(uint256 => address) internal _reservesList;

  uint256 internal __DEPRECATED_bridgeProtocolFee;

  uint128 internal __DEPRECATED_flashLoanPremium;

  uint128 internal __DEPRECATED_flashLoanPremiumToProtocol;

  uint64 internal __DEPRECATED_maxStableRateBorrowSizePercent;

  uint16 internal _reservesCount;

  mapping(address user => mapping(address permittedPositionManager => bool))
    internal _positionManager;
}
