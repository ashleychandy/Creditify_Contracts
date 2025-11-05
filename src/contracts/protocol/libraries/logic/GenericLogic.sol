// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '../../../dependencies/openzeppelin/contracts/IERC20.sol';
import {IScaledBalanceToken} from '../../../interfaces/IScaledBalanceToken.sol';
import {IPriceOracleGetter} from '../../../interfaces/IPriceOracleGetter.sol';
import {ReserveConfiguration} from '../configuration/ReserveConfiguration.sol';
import {UserConfiguration} from '../configuration/UserConfiguration.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {TokenMath} from '../helpers/TokenMath.sol';
import {MathUtils} from '../math/MathUtils.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {ReserveLogic} from './ReserveLogic.sol';

library GenericLogic {
  using ReserveLogic for DataTypes.ReserveData;
  using TokenMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  struct CalculateUserAccountDataVars {
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 userBalanceInBaseCurrency;
    uint256 decimals;
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 i;
    uint256 healthFactor;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLtv;
    uint256 avgLiquidationThreshold;
    address currentReserveAddress;
    bool hasZeroLtvCollateral;
  }

  function calculateUserAccountData(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(uint256 => address) storage reservesList,
    DataTypes.CalculateUserAccountDataParams memory params
  ) internal view returns (uint256, uint256, uint256, uint256, uint256, bool) {
    if (params.userConfig.isEmpty()) {
      return (0, 0, 0, 0, type(uint256).max, false);
    }

    CalculateUserAccountDataVars memory vars;

    uint256 userConfigCache = params.userConfig.data;
    bool isBorrowed = false;
    bool isEnabledAsCollateral = false;

    while (userConfigCache != 0) {
      (userConfigCache, isBorrowed, isEnabledAsCollateral) = UserConfiguration.getNextFlags(
        userConfigCache
      );
      if (isEnabledAsCollateral || isBorrowed) {
        vars.currentReserveAddress = reservesList[vars.i];

        if (vars.currentReserveAddress != address(0)) {
          DataTypes.ReserveData storage currentReserve = reservesData[vars.currentReserveAddress];

          (vars.ltv, vars.liquidationThreshold, , vars.decimals, ) = currentReserve
            .configuration
            .getParams();

          unchecked {
            vars.assetUnit = 10 ** vars.decimals;
          }

          vars.assetPrice = IPriceOracleGetter(params.oracle).getAssetPrice(
            vars.currentReserveAddress
          );

          if (vars.liquidationThreshold != 0 && isEnabledAsCollateral) {
            vars.userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
              params.user,
              currentReserve,
              vars.assetPrice,
              vars.assetUnit
            );

            vars.totalCollateralInBaseCurrency += vars.userBalanceInBaseCurrency;

            if (vars.ltv != 0) {
              vars.avgLtv += vars.userBalanceInBaseCurrency * vars.ltv;
            } else {
              vars.hasZeroLtvCollateral = true;
            }

            vars.avgLiquidationThreshold +=
              vars.userBalanceInBaseCurrency * vars.liquidationThreshold;
          }

          if (isBorrowed) {
            vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
              params.user,
              currentReserve,
              vars.assetPrice,
              vars.assetUnit
            );
          }
        }
      }

      unchecked {
        ++vars.i;
      }
    }

    vars.healthFactor = (vars.totalDebtInBaseCurrency == 0)
      ? type(uint256).max
      : vars.avgLiquidationThreshold.wadDiv(vars.totalDebtInBaseCurrency) / 100_00;

    unchecked {
      vars.avgLtv = vars.totalCollateralInBaseCurrency != 0
        ? vars.avgLtv / vars.totalCollateralInBaseCurrency
        : 0;
      vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency != 0
        ? vars.avgLiquidationThreshold / vars.totalCollateralInBaseCurrency
        : 0;
    }

    return (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLtv,
      vars.avgLiquidationThreshold,
      vars.healthFactor,
      vars.hasZeroLtvCollateral
    );
  }

  function calculateAvailableBorrows(
    uint256 totalCollateralInBaseCurrency,
    uint256 totalDebtInBaseCurrency,
    uint256 ltv
  ) internal pure returns (uint256) {
    uint256 availableBorrowsInBaseCurrency = totalCollateralInBaseCurrency.percentMulFloor(ltv);

    if (availableBorrowsInBaseCurrency <= totalDebtInBaseCurrency) {
      return 0;
    }

    availableBorrowsInBaseCurrency = availableBorrowsInBaseCurrency - totalDebtInBaseCurrency;
    return availableBorrowsInBaseCurrency;
  }

  function _getUserDebtInBaseCurrency(
    address user,
    DataTypes.ReserveData storage reserve,
    uint256 assetPrice,
    uint256 assetUnit
  ) private view returns (uint256) {
    uint256 userTotalDebt = IScaledBalanceToken(reserve.variableDebtTokenAddress)
      .scaledBalanceOf(user)
      .getVTokenBalance(reserve.getNormalizedDebt());

    return MathUtils.mulDivCeil(userTotalDebt, assetPrice, assetUnit);
  }

  function _getUserBalanceInBaseCurrency(
    address user,
    DataTypes.ReserveData storage reserve,
    uint256 assetPrice,
    uint256 assetUnit
  ) private view returns (uint256) {
    uint256 balance = (
      IScaledBalanceToken(reserve.aTokenAddress).scaledBalanceOf(user).getATokenBalance(
        reserve.getNormalizedIncome()
      )
    ) * assetPrice;

    unchecked {
      return balance / assetUnit;
    }
  }
}
