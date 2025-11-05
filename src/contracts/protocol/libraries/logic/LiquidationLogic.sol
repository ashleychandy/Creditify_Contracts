// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


import {IERC20} from '../../../dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeERC20} from '../../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {PercentageMath} from '../../libraries/math/PercentageMath.sol';
import {MathUtils} from '../../libraries/math/MathUtils.sol';
import {TokenMath} from '../../libraries/helpers/TokenMath.sol';
import {DataTypes} from '../../libraries/types/DataTypes.sol';
import {ReserveLogic} from './ReserveLogic.sol';
import {ValidationLogic} from './ValidationLogic.sol';
import {GenericLogic} from './GenericLogic.sol';
import {UserConfiguration} from '../../libraries/configuration/UserConfiguration.sol';
import {ReserveConfiguration} from '../../libraries/configuration/ReserveConfiguration.sol';
import {IAToken} from '../../../interfaces/IAToken.sol';
import {IPool} from '../../../interfaces/IPool.sol';
import {IVariableDebtToken} from '../../../interfaces/IVariableDebtToken.sol';
import {IPriceOracleGetter} from '../../../interfaces/IPriceOracleGetter.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Errors} from '../helpers/Errors.sol';

library LiquidationLogic {
  using TokenMath for uint256;
  using PercentageMath for uint256;
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  uint256 internal constant DEFAULT_LIQUIDATION_CLOSE_FACTOR = 0.5e4;

  uint256 public constant CLOSE_FACTOR_HF_THRESHOLD = 0.95e18;

  uint256 public constant MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD = 2000e8;

  uint256 public constant MIN_LEFTOVER_BASE = MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD / 2;

  function executeEliminateDeficit(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.UserConfigurationMap storage userConfig,
    DataTypes.ExecuteEliminateDeficitParams memory params
  ) external returns (uint256) {
    require(params.amount != 0, Errors.InvalidAmount());

    DataTypes.ReserveData storage reserve = reservesData[params.asset];
    uint256 currentDeficit = reserve.deficit;

    require(currentDeficit != 0, Errors.ReserveNotInDeficit());
    require(!userConfig.isBorrowingAny(), Errors.UserCannotHaveDebt());

    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    reserve.updateState(reserveCache);
    bool isActive = reserveCache.reserveConfiguration.getActive();
    require(isActive, Errors.ReserveInactive());

    uint256 balanceWriteOff = params.amount;

    if (params.amount > currentDeficit) {
      balanceWriteOff = currentDeficit;
    }

    uint256 userScaledBalance = IAToken(reserveCache.aTokenAddress).scaledBalanceOf(params.user);
    uint256 scaledBalanceWriteOff = balanceWriteOff.getATokenBurnScaledAmount(
      reserveCache.nextLiquidityIndex
    );
    require(scaledBalanceWriteOff <= userScaledBalance, Errors.NotEnoughAvailableUserBalance());

    bool isCollateral = userConfig.isUsingAsCollateral(reserve.id);
    if (isCollateral && scaledBalanceWriteOff == userScaledBalance) {
      userConfig.setUsingAsCollateral(reserve.id, params.asset, params.user, false);
    }

    IAToken(reserveCache.aTokenAddress).burn({
      from: params.user,
      receiverOfUnderlying: reserveCache.aTokenAddress,
      amount: balanceWriteOff,
      scaledAmount: scaledBalanceWriteOff,
      index: reserveCache.nextLiquidityIndex
    });

    reserve.deficit -= balanceWriteOff.toUint128();

    reserve.updateInterestRatesAndVirtualBalance(
      reserveCache,
      params.asset,
      0,
      0,
      params.interestRateStrategyAddress
    );

    emit IPool.DeficitCovered(params.asset, params.user, balanceWriteOff);

    return balanceWriteOff;
  }

  struct LiquidationCallLocalVars {
    uint256 borrowerCollateralBalance;
    uint256 borrowerReserveDebt;
    uint256 actualDebtToLiquidate;
    uint256 actualCollateralToLiquidate;
    uint256 liquidationBonus;
    uint256 healthFactor;
    uint256 liquidationProtocolFeeAmount;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 collateralToLiquidateInBaseCurrency;
    uint256 borrowerReserveDebtInBaseCurrency;
    uint256 borrowerReserveCollateralInBaseCurrency;
    uint256 collateralAssetPrice;
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 debtAssetUnit;
    DataTypes.ReserveCache debtReserveCache;
    DataTypes.ReserveCache collateralReserveCache;
  }

  function executeLiquidationCall(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(uint256 => address) storage reservesList,
    mapping(address => DataTypes.UserConfigurationMap) storage usersConfig,
    DataTypes.ExecuteLiquidationCallParams memory params
  ) external {
    LiquidationCallLocalVars memory vars;

    DataTypes.ReserveData storage collateralReserve = reservesData[params.collateralAsset];
    DataTypes.ReserveData storage debtReserve = reservesData[params.debtAsset];
    DataTypes.UserConfigurationMap storage borrowerConfig = usersConfig[params.borrower];
    vars.debtReserveCache = debtReserve.cache();
    vars.collateralReserveCache = collateralReserve.cache();
    debtReserve.updateState(vars.debtReserveCache);
    collateralReserve.updateState(vars.collateralReserveCache);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      ,
      ,
      vars.healthFactor,

    ) = GenericLogic.calculateUserAccountData(
      reservesData,
      reservesList,
      DataTypes.CalculateUserAccountDataParams({
        userConfig: borrowerConfig,
        user: params.borrower,
        oracle: params.priceOracle
      })
    );

    vars.borrowerCollateralBalance = IAToken(vars.collateralReserveCache.aTokenAddress)
      .scaledBalanceOf(params.borrower)
      .getATokenBalance(vars.collateralReserveCache.nextLiquidityIndex);
    vars.borrowerReserveDebt = IVariableDebtToken(vars.debtReserveCache.variableDebtTokenAddress)
      .scaledBalanceOf(params.borrower)
      .getVTokenBalance(vars.debtReserveCache.nextVariableBorrowIndex);

    ValidationLogic.validateLiquidationCall(
      borrowerConfig,
      collateralReserve,
      debtReserve,
      DataTypes.ValidateLiquidationCallParams({
        debtReserveCache: vars.debtReserveCache,
        totalDebt: vars.borrowerReserveDebt,
        healthFactor: vars.healthFactor,
        borrower: params.borrower,
        liquidator: params.liquidator
      })
    );

    vars.liquidationBonus = vars
      .collateralReserveCache
      .reserveConfiguration
      .getLiquidationBonus();
    vars.collateralAssetPrice = IPriceOracleGetter(params.priceOracle).getAssetPrice(
      params.collateralAsset
    );
    vars.debtAssetPrice = IPriceOracleGetter(params.priceOracle).getAssetPrice(params.debtAsset);
    vars.collateralAssetUnit = 10 ** vars.collateralReserveCache.reserveConfiguration.getDecimals();
    vars.debtAssetUnit = 10 ** vars.debtReserveCache.reserveConfiguration.getDecimals();

    vars.borrowerReserveDebtInBaseCurrency = MathUtils.mulDivCeil(
      vars.borrowerReserveDebt,
      vars.debtAssetPrice,
      vars.debtAssetUnit
    );

    vars.borrowerReserveCollateralInBaseCurrency =
      (vars.borrowerCollateralBalance * vars.collateralAssetPrice) /
      vars.collateralAssetUnit;

    uint256 maxLiquidatableDebt = vars.borrowerReserveDebt;

    if (
      vars.borrowerReserveCollateralInBaseCurrency >= MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD &&
      vars.borrowerReserveDebtInBaseCurrency >= MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD &&
      vars.healthFactor > CLOSE_FACTOR_HF_THRESHOLD
    ) {
      uint256 totalDefaultLiquidatableDebtInBaseCurrency = vars.totalDebtInBaseCurrency.percentMul(
        DEFAULT_LIQUIDATION_CLOSE_FACTOR
      );

      if (vars.borrowerReserveDebtInBaseCurrency > totalDefaultLiquidatableDebtInBaseCurrency) {
        maxLiquidatableDebt =
          (totalDefaultLiquidatableDebtInBaseCurrency * vars.debtAssetUnit) /
          vars.debtAssetPrice;
      }
    }

    vars.actualDebtToLiquidate = params.debtToCover > maxLiquidatableDebt
      ? maxLiquidatableDebt
      : params.debtToCover;

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount,
      vars.collateralToLiquidateInBaseCurrency
    ) = _calculateAvailableCollateralToLiquidate(
      vars.collateralReserveCache.reserveConfiguration,
      vars.collateralAssetPrice,
      vars.collateralAssetUnit,
      vars.debtAssetPrice,
      vars.debtAssetUnit,
      vars.actualDebtToLiquidate,
      vars.borrowerCollateralBalance,
      vars.liquidationBonus
    );

    if (
      vars.actualDebtToLiquidate < vars.borrowerReserveDebt &&
      vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount <
      vars.borrowerCollateralBalance
    ) {
      bool isDebtMoreThanLeftoverThreshold = MathUtils.mulDivCeil(
        vars.borrowerReserveDebt - vars.actualDebtToLiquidate,
        vars.debtAssetPrice,
        vars.debtAssetUnit
      ) >= MIN_LEFTOVER_BASE;

      bool isCollateralMoreThanLeftoverThreshold = ((vars.borrowerCollateralBalance -
        vars.actualCollateralToLiquidate -
        vars.liquidationProtocolFeeAmount) * vars.collateralAssetPrice) /
        vars.collateralAssetUnit >=
        MIN_LEFTOVER_BASE;

      require(
        isDebtMoreThanLeftoverThreshold && isCollateralMoreThanLeftoverThreshold,
        Errors.MustNotLeaveDust()
      );
    }

    if (
      vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount ==
      vars.borrowerCollateralBalance
    ) {
      borrowerConfig.setUsingAsCollateral(
        collateralReserve.id,
        params.collateralAsset,
        params.borrower,
        false
      );
    }

    bool hasNoCollateralLeft = vars.totalCollateralInBaseCurrency ==
      vars.collateralToLiquidateInBaseCurrency;
    _burnDebtTokens(
      vars.debtReserveCache,
      debtReserve,
      borrowerConfig,
      params.borrower,
      params.debtAsset,
      vars.borrowerReserveDebt,
      vars.actualDebtToLiquidate,
      hasNoCollateralLeft,
      params.interestRateStrategyAddress
    );

    if (params.receiveAToken) {
      _liquidateATokens(reservesData, reservesList, usersConfig, collateralReserve, params, vars);
    } else {

      if (params.collateralAsset == params.debtAsset) {
        vars.collateralReserveCache.nextScaledVariableDebt = vars
          .debtReserveCache
          .nextScaledVariableDebt;
      }

      _burnCollateralATokens(collateralReserve, params, vars);
    }

    if (vars.liquidationProtocolFeeAmount != 0) {
      
      uint256 scaledDownLiquidationProtocolFee = vars
        .liquidationProtocolFeeAmount
        .getATokenTransferScaledAmount(vars.collateralReserveCache.nextLiquidityIndex);
      uint256 scaledDownBorrowerBalance = IAToken(vars.collateralReserveCache.aTokenAddress)
        .scaledBalanceOf(params.borrower);
      
      if (scaledDownLiquidationProtocolFee > scaledDownBorrowerBalance) {
        scaledDownLiquidationProtocolFee = scaledDownBorrowerBalance;
        vars.liquidationProtocolFeeAmount = scaledDownBorrowerBalance.getATokenBalance(
          vars.collateralReserveCache.nextLiquidityIndex
        );
      }
      IAToken(vars.collateralReserveCache.aTokenAddress).transferOnLiquidation({
        from: params.borrower,
        to: IAToken(vars.collateralReserveCache.aTokenAddress).RESERVE_TREASURY_ADDRESS(),
        amount: vars.liquidationProtocolFeeAmount,
        scaledAmount: scaledDownLiquidationProtocolFee,
        index: vars.collateralReserveCache.nextLiquidityIndex
      });
    }

    if (hasNoCollateralLeft && borrowerConfig.isBorrowingAny()) {
      _burnBadDebt(reservesData, reservesList, borrowerConfig, params);
    }

    IERC20(params.debtAsset).safeTransferFrom(
      params.liquidator,
      vars.debtReserveCache.aTokenAddress,
      vars.actualDebtToLiquidate
    );

    emit IPool.LiquidationCall(
      params.collateralAsset,
      params.debtAsset,
      params.borrower,
      vars.actualDebtToLiquidate,
      vars.actualCollateralToLiquidate,
      params.liquidator,
      params.receiveAToken
    );
  }

  function _burnCollateralATokens(
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ExecuteLiquidationCallParams memory params,
    LiquidationCallLocalVars memory vars
  ) internal {
    collateralReserve.updateInterestRatesAndVirtualBalance(
      vars.collateralReserveCache,
      params.collateralAsset,
      0,
      vars.actualCollateralToLiquidate,
      params.interestRateStrategyAddress
    );

    IAToken(vars.collateralReserveCache.aTokenAddress).burn({
      from: params.borrower,
      receiverOfUnderlying: params.liquidator,
      amount: vars.actualCollateralToLiquidate,
      scaledAmount: vars.actualCollateralToLiquidate.getATokenBurnScaledAmount(
        vars.collateralReserveCache.nextLiquidityIndex
      ),
      index: vars.collateralReserveCache.nextLiquidityIndex
    });
  }

  function _liquidateATokens(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(uint256 => address) storage reservesList,
    mapping(address => DataTypes.UserConfigurationMap) storage usersConfig,
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ExecuteLiquidationCallParams memory params,
    LiquidationCallLocalVars memory vars
  ) internal {
    uint256 liquidatorPreviousATokenBalance = IAToken(vars.collateralReserveCache.aTokenAddress)
      .scaledBalanceOf(params.liquidator);
    IAToken(vars.collateralReserveCache.aTokenAddress).transferOnLiquidation(
      params.borrower,
      params.liquidator,
      vars.actualCollateralToLiquidate,
      vars.actualCollateralToLiquidate.getATokenTransferScaledAmount(
        vars.collateralReserveCache.nextLiquidityIndex
      ),
      vars.collateralReserveCache.nextLiquidityIndex
    );

    if (liquidatorPreviousATokenBalance == 0) {
      DataTypes.UserConfigurationMap storage liquidatorConfig = usersConfig[params.liquidator];
      if (
        ValidationLogic.validateAutomaticUseAsCollateral(
          liquidatorConfig,
          vars.collateralReserveCache.reserveConfiguration
        )
      ) {
        liquidatorConfig.setUsingAsCollateral(
          collateralReserve.id,
          params.collateralAsset,
          params.liquidator,
          true
        );
      }
    }
  }

  function _burnDebtTokens(
    DataTypes.ReserveCache memory debtReserveCache,
    DataTypes.ReserveData storage debtReserve,
    DataTypes.UserConfigurationMap storage borrowerConfig,
    address borrower,
    address debtAsset,
    uint256 borrowerReserveDebt,
    uint256 actualDebtToLiquidate,
    bool hasNoCollateralLeft,
    address interestRateStrategyAddress
  ) internal {
    bool noMoreDebt = true;

    if (borrowerReserveDebt != 0) {
      uint256 burnAmount = hasNoCollateralLeft ? borrowerReserveDebt : actualDebtToLiquidate;

      (noMoreDebt, debtReserveCache.nextScaledVariableDebt) = IVariableDebtToken(
        debtReserveCache.variableDebtTokenAddress
      ).burn({
          from: borrower,
          scaledAmount: burnAmount.getVTokenBurnScaledAmount(
            debtReserveCache.nextVariableBorrowIndex
          ),
          index: debtReserveCache.nextVariableBorrowIndex
        });
    }

    uint256 outstandingDebt = borrowerReserveDebt - actualDebtToLiquidate;
    if (hasNoCollateralLeft && outstandingDebt != 0) {
      debtReserve.deficit += outstandingDebt.toUint128();
      emit IPool.DeficitCreated(borrower, debtAsset, outstandingDebt);
    }

    if (noMoreDebt) {
      borrowerConfig.setBorrowing(debtReserve.id, false);
    }

    debtReserve.updateInterestRatesAndVirtualBalance(
      debtReserveCache,
      debtAsset,
      actualDebtToLiquidate,
      0,
      interestRateStrategyAddress
    );
  }

  struct AvailableCollateralToLiquidateLocalVars {
    uint256 maxCollateralToLiquidate;
    uint256 baseCollateral;
    uint256 bonusCollateral;
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
    uint256 liquidationProtocolFeePercentage;
    uint256 liquidationProtocolFee;
    uint256 collateralToLiquidateInBaseCurrency;
    uint256 collateralAssetPrice;
  }

  function _calculateAvailableCollateralToLiquidate(
    DataTypes.ReserveConfigurationMap memory collateralReserveConfiguration,
    uint256 collateralAssetPrice,
    uint256 collateralAssetUnit,
    uint256 debtAssetPrice,
    uint256 debtAssetUnit,
    uint256 debtToCover,
    uint256 borrowerCollateralBalance,
    uint256 liquidationBonus
  ) internal pure returns (uint256, uint256, uint256, uint256) {
    AvailableCollateralToLiquidateLocalVars memory vars;
    vars.collateralAssetPrice = collateralAssetPrice;
    vars.liquidationProtocolFeePercentage = collateralReserveConfiguration
      .getLiquidationProtocolFee();

    vars.baseCollateral =
      (debtAssetPrice * debtToCover * collateralAssetUnit) /
      (vars.collateralAssetPrice * debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(liquidationBonus);

    if (vars.maxCollateralToLiquidate > borrowerCollateralBalance) {
      vars.collateralAmount = borrowerCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralAssetPrice * vars.collateralAmount * debtAssetUnit) /
        (debtAssetPrice * collateralAssetUnit)).percentDivCeil(liquidationBonus);
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = debtToCover;
    }

    vars.collateralToLiquidateInBaseCurrency =
      (vars.collateralAmount * vars.collateralAssetPrice) /
      collateralAssetUnit;

    if (vars.liquidationProtocolFeePercentage != 0) {
      vars.bonusCollateral =
        vars.collateralAmount -
        vars.collateralAmount.percentDiv(liquidationBonus);

      vars.liquidationProtocolFee = vars.bonusCollateral.percentMul(
        vars.liquidationProtocolFeePercentage
      );
      vars.collateralAmount -= vars.liquidationProtocolFee;
    }
    return (
      vars.collateralAmount,
      vars.debtAmountNeeded,
      vars.liquidationProtocolFee,
      vars.collateralToLiquidateInBaseCurrency
    );
  }

  function _burnBadDebt(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(uint256 => address) storage reservesList,
    DataTypes.UserConfigurationMap storage borrowerConfig,
    DataTypes.ExecuteLiquidationCallParams memory params
  ) internal {
    uint256 cachedBorrowerConfig = borrowerConfig.data;
    uint256 i = 0;
    bool isBorrowed = false;
    while (cachedBorrowerConfig != 0) {
      (cachedBorrowerConfig, isBorrowed, ) = UserConfiguration.getNextFlags(cachedBorrowerConfig);
      if (isBorrowed) {
        address reserveAddress = reservesList[i];
        if (reserveAddress != address(0)) {
          DataTypes.ReserveCache memory reserveCache = reservesData[reserveAddress].cache();
          if (reserveCache.reserveConfiguration.getActive()) {
            reservesData[reserveAddress].updateState(reserveCache);

            _burnDebtTokens(
              reserveCache,
              reservesData[reserveAddress],
              borrowerConfig,
              params.borrower,
              reserveAddress,
              IVariableDebtToken(reserveCache.variableDebtTokenAddress)
                .scaledBalanceOf(params.borrower)
                .getVTokenBalance(reserveCache.nextVariableBorrowIndex),
              0,
              true,
              params.interestRateStrategyAddress
            );
          }
        }
      }
      unchecked {
        ++i;
      }
    }
  }
}
