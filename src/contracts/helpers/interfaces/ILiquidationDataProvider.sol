// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../../interfaces/IPool.sol";

interface ILiquidationDataProvider {
    struct UserPositionFullInfo {
        uint256 totalCollateralInBaseCurrency;
        uint256 totalDebtInBaseCurrency;
        uint256 availableBorrowsInBaseCurrency;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
    }

    struct CollateralFullInfo {
        address aToken;
        uint256 collateralBalance;
        uint256 collateralBalanceInBaseCurrency;
        uint256 price;
        uint256 assetUnit;
    }

    struct DebtFullInfo {
        address variableDebtToken;
        uint256 debtBalance;
        uint256 debtBalanceInBaseCurrency;
        uint256 price;
        uint256 assetUnit;
    }

    struct LiquidationInfo {
        UserPositionFullInfo userInfo;
        CollateralFullInfo collateralInfo;
        DebtFullInfo debtInfo;
        uint256 maxCollateralToLiquidate;
        uint256 maxDebtToLiquidate;
        uint256 liquidationProtocolFee;
        uint256 amountToPassToLiquidationCall;
    }

    struct GetLiquidationInfoLocalVars {
        uint256 liquidationBonus;
        uint256 maxDebtToLiquidate;
        uint256 collateralAmountToLiquidate;
        uint256 debtAmountToLiquidate;
        uint256 liquidationProtocolFee;
    }

    struct AdjustAmountsForGoodLeftoversLocalVars {
        uint256 collateralLeftoverInBaseCurrency;
        uint256 debtLeftoverInBaseCurrency;
        uint256 collateralDecreaseAmountInBaseCurrency;
        uint256 debtDecreaseAmountInBaseCurrency;
        uint256 collateralDecreaseAmount;
        uint256 debtDecreaseAmount;
        uint256 liquidationProtocolFeePercentage;
        uint256 bonusCollateral;
    }

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

    function POOL() external view returns (IPool);

    function getUserPositionFullInfo(address user) external view returns (UserPositionFullInfo memory);

    function getCollateralFullInfo(address user, address collateralAsset)
        external
        view
        returns (CollateralFullInfo memory);

    function getDebtFullInfo(address user, address debtAsset) external view returns (DebtFullInfo memory);

    function getLiquidationInfo(address user, address collateralAsset, address debtAsset)
        external
        view
        returns (LiquidationInfo memory);

    function getLiquidationInfo(address user, address collateralAsset, address debtAsset, uint256 debtLiquidationAmount)
        external
        view
        returns (LiquidationInfo memory);
}
