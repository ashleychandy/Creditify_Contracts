// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Detailed} from '../dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {ReserveConfiguration} from '../protocol/libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from '../protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {WadRayMath} from '../protocol/libraries/math/WadRayMath.sol';
import {IPoolAddressesProvider} from '../interfaces/IPoolAddressesProvider.sol';
import {IVariableDebtToken} from '../interfaces/IVariableDebtToken.sol';
import {IPool} from '../interfaces/IPool.sol';
import {IPoolDataProvider} from '../interfaces/IPoolDataProvider.sol';
import {Errors} from '../protocol/libraries/helpers/Errors.sol';

contract CreditifyProtocolDataProvider is IPoolDataProvider {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using WadRayMath for uint256;

  address constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
  address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  IPool public immutable POOL;

  constructor(IPoolAddressesProvider addressesProvider) {
    ADDRESSES_PROVIDER = addressesProvider;

    address pool = addressesProvider.getPool();
    require(pool != address(0), Errors.ZeroAddressNotValid());

    POOL = IPool(pool);
  }

  function getAllReservesTokens() external view override returns (TokenData[] memory) {
    address[] memory reserves = POOL.getReservesList();
    TokenData[] memory reservesTokens = new TokenData[](reserves.length);
    for (uint256 i = 0; i < reserves.length; i++) {
      if (reserves[i] == MKR) {
        reservesTokens[i] = TokenData({symbol: 'MKR', tokenAddress: reserves[i]});
        continue;
      }
      if (reserves[i] == ETH) {
        reservesTokens[i] = TokenData({symbol: 'ETH', tokenAddress: reserves[i]});
        continue;
      }
      reservesTokens[i] = TokenData({
        symbol: IERC20Detailed(reserves[i]).symbol(),
        tokenAddress: reserves[i]
      });
    }
    return reservesTokens;
  }

  function getAllATokens() external view override returns (TokenData[] memory) {
    address[] memory reserves = POOL.getReservesList();
    TokenData[] memory aTokens = new TokenData[](reserves.length);
    for (uint256 i = 0; i < reserves.length; i++) {
      address aTokenAddress = POOL.getReserveAToken(reserves[i]);
      aTokens[i] = TokenData({
        symbol: IERC20Detailed(aTokenAddress).symbol(),
        tokenAddress: aTokenAddress
      });
    }
    return aTokens;
  }

  function getReserveConfigurationData(
    address asset
  )
    external
    view
    override
    returns (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      bool stableBorrowRateEnabled,
      bool isActive,
      bool isFrozen
    )
  {
    DataTypes.ReserveConfigurationMap memory configuration = POOL.getConfiguration(asset);

    (ltv, liquidationThreshold, liquidationBonus, decimals, reserveFactor) = configuration
      .getParams();

    (isActive, isFrozen, borrowingEnabled, ) = configuration.getFlags();

    stableBorrowRateEnabled = false;

    usageAsCollateralEnabled = liquidationThreshold != 0;
  }

  function getReserveCaps(
    address asset
  ) external view override returns (uint256 borrowCap, uint256 supplyCap) {
    (borrowCap, supplyCap) = POOL.getConfiguration(asset).getCaps();
  }

  function getPaused(address asset) external view override returns (bool isPaused) {
    (, , , isPaused) = POOL.getConfiguration(asset).getFlags();
  }

  function getSiloedBorrowing(address asset) external view override returns (bool) {
    return false;
  }

  function getLiquidationProtocolFee(address asset) external view override returns (uint256) {
    return POOL.getConfiguration(asset).getLiquidationProtocolFee();
  }

  function getUnbackedMintCap(address) external pure override returns (uint256) {
    return 0;
  }

  function getDebtCeiling(address asset) external view override returns (uint256) {
    return 0;
  }

  function getDebtCeilingDecimals() external pure override returns (uint256) {
    return 0;
  }

  function getReserveData(
    address asset
  )
    external
    view
    override
    returns (
      uint256,
      uint256 accruedToTreasuryScaled,
      uint256 totalAToken,
      uint256,
      uint256 totalVariableDebt,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256,
      uint256,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      uint40 lastUpdateTimestamp
    )
  {
    DataTypes.ReserveDataLegacy memory reserve = POOL.getReserveData(asset);

    return (
      0,
      reserve.accruedToTreasury,
      IERC20Detailed(reserve.aTokenAddress).totalSupply(),
      0,
      IERC20Detailed(reserve.variableDebtTokenAddress).totalSupply(),
      reserve.currentLiquidityRate,
      reserve.currentVariableBorrowRate,
      0,
      0,
      reserve.liquidityIndex,
      reserve.variableBorrowIndex,
      reserve.lastUpdateTimestamp
    );
  }

  function getATokenTotalSupply(address asset) external view override returns (uint256) {
    address aTokenAddress = POOL.getReserveAToken(asset);
    return IERC20Detailed(aTokenAddress).totalSupply();
  }

  function getTotalDebt(address asset) external view override returns (uint256) {
    address variableDebtTokenAddress = POOL.getReserveVariableDebtToken(asset);
    return IERC20Detailed(variableDebtTokenAddress).totalSupply();
  }

  function getUserReserveData(
    address asset,
    address user
  )
    external
    view
    override
    returns (
      uint256 currentATokenBalance,
      uint256 currentStableDebt,
      uint256 currentVariableDebt,
      uint256 principalStableDebt,
      uint256 scaledVariableDebt,
      uint256 stableBorrowRate,
      uint256 liquidityRate,
      uint40 stableRateLastUpdated,
      bool usageAsCollateralEnabled
    )
  {
    DataTypes.ReserveDataLegacy memory reserve = POOL.getReserveData(asset);

    DataTypes.UserConfigurationMap memory userConfig = POOL.getUserConfiguration(user);

    currentATokenBalance = IERC20Detailed(reserve.aTokenAddress).balanceOf(user);
    currentVariableDebt = IERC20Detailed(reserve.variableDebtTokenAddress).balanceOf(user);

    currentStableDebt = principalStableDebt = stableBorrowRate = stableRateLastUpdated = 0;

    scaledVariableDebt = IVariableDebtToken(reserve.variableDebtTokenAddress).scaledBalanceOf(user);
    liquidityRate = reserve.currentLiquidityRate;
    usageAsCollateralEnabled = userConfig.isUsingAsCollateral(reserve.id);
  }

  function getReserveTokensAddresses(
    address asset
  )
    external
    view
    override
    returns (
      address aTokenAddress,
      address stableDebtTokenAddress,
      address variableDebtTokenAddress
    )
  {
    return (POOL.getReserveAToken(asset), address(0), POOL.getReserveVariableDebtToken(asset));
  }

  function getInterestRateStrategyAddress(
    address
  ) external view override returns (address irStrategyAddress) {
    return POOL.RESERVE_INTEREST_RATE_STRATEGY();
  }

  function getIsVirtualAccActive(address) external pure override returns (bool) {
    return true;
  }

  function getVirtualUnderlyingBalance(address asset) external view override returns (uint256) {
    return POOL.getVirtualUnderlyingBalance(asset);
  }

  function getReserveDeficit(address asset) external view override returns (uint256) {
    return POOL.getReserveDeficit(asset);
  }
}
