// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IPool} from '../../interfaces/IPool.sol';
import {IPoolConfigurator} from '../../interfaces/IPoolConfigurator.sol';
import {ICreditifyOracle} from '../../interfaces/ICreditifyOracle.sol';
import {IDefaultInterestRateStrategyV2} from '../../interfaces/IDefaultInterestRateStrategyV2.sol';

interface ICreditifyV3ConfigEngine {
  struct Basic {
    string assetSymbol;
    TokenImplementations implementations;
  }

  struct EngineLibraries {
    address listingEngine;
    address borrowEngine;
    address collateralEngine;
    address priceFeedEngine;
    address rateEngine;
    address capsEngine;
  }

  struct EngineConstants {
    IPool pool;
    IPoolConfigurator poolConfigurator;
    ICreditifyOracle oracle;
    address rewardsController;
    address collector;
    address defaultInterestRateStrategy;
  }

  struct InterestRateInputData {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  struct PoolContext {
    string networkName;
    string networkAbbreviation;
  }

  struct Listing {
    address asset;
    string assetSymbol;
    address priceFeed;
    InterestRateInputData rateStrategyParams;
    uint256 enabledToBorrow;
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
    uint256 reserveFactor;
    uint256 supplyCap;
    uint256 borrowCap;
    uint256 liqProtocolFee;
  }

  struct RepackedListings {
    address[] ids;
    Basic[] basics;
    BorrowUpdate[] borrowsUpdates;
    CollateralUpdate[] collateralsUpdates;
    PriceFeedUpdate[] priceFeedsUpdates;
    CapsUpdate[] capsUpdates;
    IDefaultInterestRateStrategyV2.InterestRateData[] rates;
  }

  struct TokenImplementations {
    address aToken;
    address vToken;
  }

  struct ListingWithCustomImpl {
    Listing base;
    TokenImplementations implementations;
  }

  struct CapsUpdate {
    address asset;
    uint256 supplyCap;
    uint256 borrowCap;
  }

  struct PriceFeedUpdate {
    address asset;
    address priceFeed;
  }

  struct CollateralUpdate {
    address asset;
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
    uint256 liqProtocolFee;
  }

  struct BorrowUpdate {
    address asset;
    uint256 enabledToBorrow;
    uint256 reserveFactor;
  }

  struct RateStrategyUpdate {
    address asset;
    InterestRateInputData params;
  }

  function listAssets(PoolContext memory context, Listing[] memory listings) external;

  function listAssetsCustom(
    PoolContext memory context,
    ListingWithCustomImpl[] memory listings
  ) external;

  function updateCaps(CapsUpdate[] memory updates) external;

  function updateRateStrategies(RateStrategyUpdate[] memory updates) external;

  function updateCollateralSide(CollateralUpdate[] memory updates) external;

  function updatePriceFeeds(PriceFeedUpdate[] memory updates) external;

  function updateBorrowSide(BorrowUpdate[] memory updates) external;

  function DEFAULT_INTEREST_RATE_STRATEGY() external view returns (address);

  function POOL() external view returns (IPool);

  function POOL_CONFIGURATOR() external view returns (IPoolConfigurator);

  function ORACLE() external view returns (ICreditifyOracle);

  function ATOKEN_IMPL() external view returns (address);

  function VTOKEN_IMPL() external view returns (address);

  function REWARDS_CONTROLLER() external view returns (address);

  function COLLECTOR() external view returns (address);

  function BORROW_ENGINE() external view returns (address);

  function CAPS_ENGINE() external view returns (address);

  function COLLATERAL_ENGINE() external view returns (address);

  function LISTING_ENGINE() external view returns (address);

  function PRICE_FEED_ENGINE() external view returns (address);

  function RATE_ENGINE() external view returns (address);
}
