// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../contracts/interfaces/IPoolAddressesProvider.sol';
import '../../contracts/interfaces/IPoolAddressesProviderRegistry.sol';
import '../../contracts/interfaces/IPool.sol';
import '../../contracts/interfaces/IPoolConfigurator.sol';
import '../../contracts/interfaces/ICreditifyOracle.sol';
import '../../contracts/interfaces/IAToken.sol';
import '../../contracts/interfaces/IVariableDebtToken.sol';
import '../../contracts/interfaces/IACLManager.sol';
import '../../contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import '../../contracts/helpers/CreditifyProtocolDataProvider.sol';
import '../../contracts/helpers/UiPoolDataProviderV3.sol';
import '../../contracts/helpers/UiIncentiveDataProviderV3.sol';
import '../../contracts/rewards/interfaces/IEmissionManager.sol';
import '../../contracts/rewards/interfaces/IRewardsController.sol';
import '../../contracts/helpers/WalletBalanceProvider.sol';
import '../../contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol';
import {ICollector} from '../../contracts/treasury/ICollector.sol';

struct ContractsReport {
  IPoolAddressesProviderRegistry poolAddressesProviderRegistry;
  IPoolAddressesProvider poolAddressesProvider;
  IPool poolProxy;
  IPool poolImplementation;
  IPoolConfigurator poolConfiguratorProxy;
  IPoolConfigurator poolConfiguratorImplementation;
  CreditifyProtocolDataProvider protocolDataProvider;
  ICreditifyOracle creditifyOracle;
  IACLManager aclManager;
  ICollector treasury;
  IDefaultInterestRateStrategyV2 defaultInterestRateStrategy;
  ICollector treasuryImplementation;
  IWrappedTokenGatewayV3 wrappedTokenGateway;
  WalletBalanceProvider walletBalanceProvider;
  UiIncentiveDataProviderV3 uiIncentiveDataProvider;
  UiPoolDataProviderV3 uiPoolDataProvider;
  IAToken aToken;
  IVariableDebtToken variableDebtToken;
  IEmissionManager emissionManager;
  IRewardsController rewardsControllerImplementation;
  IRewardsController rewardsControllerProxy;
}

struct MarketReport {
  address poolAddressesProviderRegistry;
  address poolAddressesProvider;
  address poolProxy;
  address poolImplementation;
  address poolConfiguratorProxy;
  address poolConfiguratorImplementation;
  address protocolDataProvider;
  address creditifyOracle;
  address defaultInterestRateStrategy;
  address aclManager;
  address treasury;
  address treasuryImplementation;
  address wrappedTokenGateway;
  address walletBalanceProvider;
  address uiIncentiveDataProvider;
  address uiPoolDataProvider;
  address aToken;
  address variableDebtToken;
  address emissionManager;
  address rewardsControllerImplementation;
  address rewardsControllerProxy;
  address configEngine;
  address transparentProxyFactory;
  address staticATokenFactoryImplementation;
  address staticATokenFactoryProxy;
  address staticATokenImplementation;
  address revenueSplitter;
  address dustBin;
  address emptyImplementation;
}

struct LibrariesReport {
  address borrowLogic;
  address configuratorLogic;
  address liquidationLogic;
  address poolLogic;
  address supplyLogic;
}

struct Roles {
  address marketOwner;
  address poolAdmin;
  address emergencyAdmin;
}

struct MarketConfig {
  address networkBaseTokenPriceInUsdProxyAggregator;
  address marketReferenceCurrencyPriceInUsdProxyAggregator;
  string marketId;
  uint8 oracleDecimals;
  uint256 providerId;
  bytes32 salt;
  address wrappedNativeToken;
  address incentivesProxy;
  address treasury; 
  address treasuryPartner; 
  uint16 treasurySplitPercent; 
}

struct DeployFlags {
  bool placeholder; 
}

struct PoolReport {
  address poolImplementation;
  address poolConfiguratorImplementation;
}

struct MiscReport {
  address defaultInterestRateStrategy;
}

struct ConfigEngineReport {
  address configEngine;
  address listingEngine;
  address borrowEngine;
  address collateralEngine;
  address priceFeedEngine;
  address rateEngine;
  address capsEngine;
}

struct StaticATokenReport {
  address transparentProxyFactory;
  address staticATokenImplementation;
  address staticATokenFactoryImplementation;
  address staticATokenFactoryProxy;
}

struct InitialReport {
  address poolAddressesProvider;
  address interestRateStrategy;
  address poolAddressesProviderRegistry;
}

struct SetupReport {
  address poolProxy;
  address poolConfiguratorProxy;
  address rewardsControllerProxy;
  address aclManager;
}

struct PeripheryReport {
  address creditifyOracle;
  address treasury;
  address treasuryImplementation;
  address emissionManager;
  address rewardsControllerImplementation;
  address revenueSplitter;
  address emptyImplementation;
  address dustBin;
}
