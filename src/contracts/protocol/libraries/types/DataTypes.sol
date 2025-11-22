// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
    struct ReserveDataLegacy {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
    }

    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 deficit;
        uint40 lastUpdateTimestamp;
        uint16 id;
        uint40 liquidationGracePeriodUntil;
        address aTokenAddress;
        address __deprecatedStableDebtTokenAddress;
        address variableDebtTokenAddress;
        address __deprecatedInterestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 virtualUnderlyingBalance;
        uint128 __deprecatedVirtualUnderlyingBalance;
    }

    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct UserConfigurationMap {
        uint256 data;
    }

    enum InterestRateMode {
        NONE,
        __DEPRECATED,
        VARIABLE
    }

    struct ReserveCache {
        uint256 currScaledVariableDebt;
        uint256 nextScaledVariableDebt;
        uint256 currLiquidityIndex;
        uint256 nextLiquidityIndex;
        uint256 currVariableBorrowIndex;
        uint256 nextVariableBorrowIndex;
        uint256 currLiquidityRate;
        uint256 currVariableBorrowRate;
        uint256 reserveFactor;
        ReserveConfigurationMap reserveConfiguration;
        address aTokenAddress;
        address variableDebtTokenAddress;
        uint40 reserveLastUpdateTimestamp;
    }

    struct ExecuteLiquidationCallParams {
        address liquidator;
        uint256 debtToCover;
        address collateralAsset;
        address debtAsset;
        address borrower;
        bool receiveAToken;
        address priceOracle;
        address interestRateStrategyAddress;
    }

    struct ExecuteSupplyParams {
        address user;
        address asset;
        address interestRateStrategyAddress;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct ExecuteBorrowParams {
        address asset;
        address user;
        address onBehalfOf;
        address interestRateStrategyAddress;
        uint256 amount;
        InterestRateMode interestRateMode;
        uint16 referralCode;
        bool releaseUnderlying;
        address oracle;
    }

    struct ExecuteRepayParams {
        address asset;
        address user;
        address interestRateStrategyAddress;
        uint256 amount;
        InterestRateMode interestRateMode;
        address onBehalfOf;
        bool useATokens;
        address oracle;
    }

    struct ExecuteWithdrawParams {
        address user;
        address asset;
        address interestRateStrategyAddress;
        uint256 amount;
        address to;
        address oracle;
    }

    struct ExecuteEliminateDeficitParams {
        address user;
        address asset;
        address interestRateStrategyAddress;
        uint256 amount;
    }

    struct FinalizeTransferParams {
        address asset;
        address from;
        address to;
        uint256 scaledAmount;
        uint256 scaledBalanceFromBefore;
        uint256 scaledBalanceToBefore;
        address oracle;
    }

    struct CalculateUserAccountDataParams {
        UserConfigurationMap userConfig;
        address user;
        address oracle;
    }

    struct ValidateBorrowParams {
        ReserveCache reserveCache;
        UserConfigurationMap userConfig;
        address asset;
        address userAddress;
        uint256 amountScaled;
        InterestRateMode interestRateMode;
        address oracle;
    }

    struct ValidateLiquidationCallParams {
        ReserveCache debtReserveCache;
        uint256 totalDebt;
        uint256 healthFactor;
        address borrower;
        address liquidator;
    }

    struct CalculateInterestRatesParams {
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        uint256 totalDebt;
        uint256 reserveFactor;
        address reserve;
        bool usingVirtualBalance;
        uint256 virtualUnderlyingBalance;
    }

    struct InitReserveParams {
        address asset;
        address aTokenAddress;
        address variableDebtAddress;
        uint16 reservesCount;
        uint16 maxNumberReserves;
    }
}
