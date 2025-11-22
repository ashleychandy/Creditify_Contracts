// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SafeERC20} from "../../../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {Address} from "../../../dependencies/openzeppelin/contracts/Address.sol";
import {IERC20} from "../../../dependencies/openzeppelin/contracts/IERC20.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {Errors} from "../helpers/Errors.sol";
import {TokenMath} from "../helpers/TokenMath.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";

library PoolLogic {
    using SafeERC20 for IERC20;
    using TokenMath for uint256;
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function executeInitReserve(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.InitReserveParams memory params
    ) external returns (bool) {
        require(Address.isContract(params.asset), Errors.NotContract());
        reservesData[params.asset].init(params.aTokenAddress, params.variableDebtAddress);

        bool reserveAlreadyAdded = reservesData[params.asset].id != 0 || reservesList[0] == params.asset;
        require(!reserveAlreadyAdded, Errors.ReserveAlreadyAdded());

        for (uint16 i = 0; i < params.reservesCount; i++) {
            if (reservesList[i] == address(0)) {
                reservesData[params.asset].id = i;
                reservesList[i] = params.asset;
                return false;
            }
        }

        require(params.reservesCount < params.maxNumberReserves, Errors.NoMoreReservesAllowed());
        reservesData[params.asset].id = params.reservesCount;
        reservesList[params.reservesCount] = params.asset;
        return true;
    }

    function executeSyncIndexesState(DataTypes.ReserveData storage reserve) external {
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        reserve.updateState(reserveCache);
    }

    function executeSyncRatesState(
        DataTypes.ReserveData storage reserve,
        address asset,
        address interestRateStrategyAddress
    ) external {
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        reserve.updateInterestRatesAndVirtualBalance(reserveCache, asset, 0, 0, interestRateStrategyAddress);
    }

    function executeRescueTokens(address token, address to, uint256 amount) external {
        IERC20(token).safeTransfer(to, amount);
    }

    function executeMintToTreasury(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        address[] calldata assets
    ) external {
        for (uint256 i = 0; i < assets.length; i++) {
            address assetAddress = assets[i];

            DataTypes.ReserveData storage reserve = reservesData[assetAddress];

            if (!reserve.configuration.getActive()) {
                continue;
            }

            uint256 accruedToTreasury = reserve.accruedToTreasury;

            if (accruedToTreasury != 0) {
                reserve.accruedToTreasury = 0;
                uint256 normalizedIncome = reserve.getNormalizedIncome();
                uint256 amountToMint = accruedToTreasury.getATokenBalance(normalizedIncome);
                IAToken(reserve.aTokenAddress).mintToTreasury(accruedToTreasury, normalizedIncome);

                emit IPool.MintedToTreasury(assetAddress, amountToMint);
            }
        }
    }

    function executeSetLiquidationGracePeriod(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        address asset,
        uint40 until
    ) external {
        reservesData[asset].liquidationGracePeriodUntil = until;
    }

    function executeDropReserve(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        address asset
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[asset];
        ValidationLogic.validateDropReserve(reservesList, reserve, asset);
        reservesList[reservesData[asset].id] = address(0);
        delete reservesData[asset];
    }

    function executeGetUserAccountData(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.CalculateUserAccountDataParams memory params
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        (totalCollateralBase, totalDebtBase, ltv, currentLiquidationThreshold, healthFactor,) =
            GenericLogic.calculateUserAccountData(reservesData, reservesList, params);

        availableBorrowsBase = GenericLogic.calculateAvailableBorrows(totalCollateralBase, totalDebtBase, ltv);
    }
}
