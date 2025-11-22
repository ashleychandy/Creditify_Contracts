// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "../../../dependencies/openzeppelin/contracts/IERC20.sol";
import {Address} from "../../../dependencies/openzeppelin/contracts/Address.sol";
import {SafeERC20} from "../../../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {IPriceOracleGetter} from "../../../interfaces/IPriceOracleGetter.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPoolAddressesProvider} from "../../../interfaces/IPoolAddressesProvider.sol";
import {IAccessControl} from "../../../dependencies/openzeppelin/contracts/IAccessControl.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {Errors} from "../helpers/Errors.sol";
import {TokenMath} from "../helpers/TokenMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {IncentivizedERC20} from "../../tokenization/base/IncentivizedERC20.sol";
import {MathUtils} from "../math/MathUtils.sol";

library ValidationLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using TokenMath for uint256;
    using PercentageMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using Address for address;

    uint256 public constant REBALANCE_UP_LIQUIDITY_RATE_THRESHOLD = 0.9e4;

    uint256 public constant MINIMUM_HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 0.95e18;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

    function validateSupply(
        DataTypes.ReserveCache memory reserveCache,
        DataTypes.ReserveData storage reserve,
        uint256 scaledAmount,
        address onBehalfOf
    ) internal view {
        require(scaledAmount != 0, Errors.InvalidAmount());

        (bool isActive, bool isFrozen,, bool isPaused) = reserveCache.reserveConfiguration.getFlags();
        require(isActive, Errors.ReserveInactive());
        require(!isPaused, Errors.ReservePaused());
        require(!isFrozen, Errors.ReserveFrozen());
        require(onBehalfOf != reserveCache.aTokenAddress, Errors.SupplyToAToken());

        uint256 supplyCap = reserveCache.reserveConfiguration.getSupplyCap();
        require(
            supplyCap == 0
                || (
                    (
                        IAToken(reserveCache.aTokenAddress).scaledTotalSupply() + scaledAmount
                            + uint256(reserve.accruedToTreasury)
                    ).getATokenBalance(reserveCache.nextLiquidityIndex)
                ) <= supplyCap * (10 ** reserveCache.reserveConfiguration.getDecimals()),
            Errors.SupplyCapExceeded()
        );
    }

    function validateWithdraw(
        DataTypes.ReserveCache memory reserveCache,
        uint256 scaledAmount,
        uint256 scaledUserBalance
    ) internal pure {
        require(scaledAmount != 0, Errors.InvalidAmount());
        require(scaledAmount <= scaledUserBalance, Errors.NotEnoughAvailableUserBalance());

        (bool isActive,,, bool isPaused) = reserveCache.reserveConfiguration.getFlags();
        require(isActive, Errors.ReserveInactive());
        require(!isPaused, Errors.ReservePaused());
    }

    struct ValidateBorrowLocalVars {
        uint256 amount;
        uint256 totalDebt;
        uint256 reserveDecimals;
        uint256 borrowCap;
        uint256 assetUnit;
        bool isActive;
        bool isFrozen;
        bool isPaused;
        bool borrowingEnabled;
    }

    function validateBorrow(DataTypes.ValidateBorrowParams memory params) internal view {
        require(params.amountScaled != 0, Errors.InvalidAmount());

        ValidateBorrowLocalVars memory vars;
        vars.amount = params.amountScaled.getVTokenBalance(params.reserveCache.nextVariableBorrowIndex);

        (vars.isActive, vars.isFrozen, vars.borrowingEnabled, vars.isPaused) =
            params.reserveCache.reserveConfiguration.getFlags();

        require(vars.isActive, Errors.ReserveInactive());
        require(!vars.isPaused, Errors.ReservePaused());
        require(!vars.isFrozen, Errors.ReserveFrozen());
        require(vars.borrowingEnabled, Errors.BorrowingNotEnabled());
        require(IERC20(params.reserveCache.aTokenAddress).totalSupply() >= vars.amount, Errors.InvalidAmount());

        require(
            params.interestRateMode == DataTypes.InterestRateMode.VARIABLE, Errors.InvalidInterestRateModeSelected()
        );

        vars.reserveDecimals = params.reserveCache.reserveConfiguration.getDecimals();
        vars.borrowCap = params.reserveCache.reserveConfiguration.getBorrowCap();
        unchecked {
            vars.assetUnit = 10 ** vars.reserveDecimals;
        }

        if (vars.borrowCap != 0) {
            vars.totalDebt = (params.reserveCache.currScaledVariableDebt + params.amountScaled).getVTokenBalance(
                params.reserveCache.nextVariableBorrowIndex
            );

            unchecked {
                require(vars.totalDebt <= vars.borrowCap * vars.assetUnit, Errors.BorrowCapExceeded());
            }
        }
    }

    function validateRepay(
        address user,
        DataTypes.ReserveCache memory reserveCache,
        uint256 amountSent,
        DataTypes.InterestRateMode interestRateMode,
        address onBehalfOf,
        uint256 debtScaled
    ) internal pure {
        require(amountSent != 0, Errors.InvalidAmount());
        require(interestRateMode == DataTypes.InterestRateMode.VARIABLE, Errors.InvalidInterestRateModeSelected());
        require(amountSent != type(uint256).max || user == onBehalfOf, Errors.NoExplicitAmountToRepayOnBehalf());

        (bool isActive,,, bool isPaused) = reserveCache.reserveConfiguration.getFlags();
        require(isActive, Errors.ReserveInactive());
        require(!isPaused, Errors.ReservePaused());

        require(debtScaled != 0, Errors.NoDebtOfSelectedType());
    }

    function validateSetUseReserveAsCollateral(DataTypes.ReserveConfigurationMap memory reserveConfig) internal pure {
        (bool isActive,,, bool isPaused) = reserveConfig.getFlags();
        require(isActive, Errors.ReserveInactive());
        require(!isPaused, Errors.ReservePaused());
    }

    struct ValidateLiquidationCallLocalVars {
        bool collateralReserveActive;
        bool collateralReservePaused;
        bool principalReserveActive;
        bool principalReservePaused;
        bool isCollateralEnabled;
    }

    function validateLiquidationCall(
        DataTypes.UserConfigurationMap storage borrowerConfig,
        DataTypes.ReserveData storage collateralReserve,
        DataTypes.ReserveData storage debtReserve,
        DataTypes.ValidateLiquidationCallParams memory params
    ) internal view {
        ValidateLiquidationCallLocalVars memory vars;

        require(params.borrower != params.liquidator, Errors.SelfLiquidation());

        (vars.collateralReserveActive,,, vars.collateralReservePaused) = collateralReserve.configuration.getFlags();

        (vars.principalReserveActive,,, vars.principalReservePaused) =
            params.debtReserveCache.reserveConfiguration.getFlags();

        require(vars.collateralReserveActive && vars.principalReserveActive, Errors.ReserveInactive());
        require(!vars.collateralReservePaused && !vars.principalReservePaused, Errors.ReservePaused());

        require(
            collateralReserve.liquidationGracePeriodUntil < uint40(block.timestamp)
                && debtReserve.liquidationGracePeriodUntil < uint40(block.timestamp),
            Errors.LiquidationGraceSentinelCheckFailed()
        );

        require(params.healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD, Errors.HealthFactorNotBelowThreshold());

        vars.isCollateralEnabled = collateralReserve.configuration.getLiquidationThreshold() != 0
            && borrowerConfig.isUsingAsCollateral(collateralReserve.id);

        require(vars.isCollateralEnabled, Errors.CollateralCannotBeLiquidated());
        require(params.totalDebt != 0, Errors.SpecifiedCurrencyNotBorrowedByUser());
    }

    function validateHealthFactor(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap memory userConfig,
        address user,
        address oracle
    ) internal view returns (uint256, bool) {
        (,,,, uint256 healthFactor, bool hasZeroLtvCollateral) = GenericLogic.calculateUserAccountData(
            reservesData,
            reservesList,
            DataTypes.CalculateUserAccountDataParams({userConfig: userConfig, user: user, oracle: oracle})
        );

        require(healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, Errors.HealthFactorLowerThanLiquidationThreshold());

        return (healthFactor, hasZeroLtvCollateral);
    }

    function validateHFAndLtv(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap memory userConfig,
        address user,
        address oracle
    ) internal view {
        (
            uint256 userCollateralInBaseCurrency,
            uint256 userDebtInBaseCurrency,
            uint256 currentLtv,
            ,
            uint256 healthFactor,
        ) = GenericLogic.calculateUserAccountData(
            reservesData,
            reservesList,
            DataTypes.CalculateUserAccountDataParams({userConfig: userConfig, user: user, oracle: oracle})
        );

        require(currentLtv != 0, Errors.LtvValidationFailed());

        require(healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, Errors.HealthFactorLowerThanLiquidationThreshold());

        require(
            userCollateralInBaseCurrency >= userDebtInBaseCurrency.percentDivCeil(currentLtv),
            Errors.CollateralCannotCoverNewBorrow()
        );
    }

    function validateHFAndLtvzero(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap memory userConfig,
        address asset,
        address from,
        address oracle
    ) internal view {
        (, bool hasZeroLtvCollateral) = validateHealthFactor(reservesData, reservesList, userConfig, from, oracle);

        require(!hasZeroLtvCollateral || reservesData[asset].configuration.getLtv() == 0, Errors.LtvValidationFailed());
    }

    function validateTransfer(DataTypes.ReserveData storage reserve) internal view {
        require(!reserve.configuration.getPaused(), Errors.ReservePaused());
    }

    function validateDropReserve(
        mapping(uint256 => address) storage reservesList,
        DataTypes.ReserveData storage reserve,
        address asset
    ) internal view {
        require(asset != address(0), Errors.ZeroAddressNotValid());
        require(reserve.id != 0 || reservesList[0] == asset, Errors.AssetNotListed());
        require(IERC20(reserve.variableDebtTokenAddress).totalSupply() == 0, Errors.VariableDebtSupplyNotZero());
        require(
            IERC20(reserve.aTokenAddress).totalSupply() == 0 && reserve.accruedToTreasury == 0,
            Errors.UnderlyingClaimableRightsNotZero()
        );
    }

    function validateUseAsCollateral(
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ReserveConfigurationMap memory reserveConfig
    ) internal view returns (bool) {
        if (reserveConfig.getLtv() == 0) {
            return false;
        }
        return true;
    }

    function validateAutomaticUseAsCollateral(
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ReserveConfigurationMap memory reserveConfig
    ) internal view returns (bool) {
        return validateUseAsCollateral(userConfig, reserveConfig);
    }
}
