// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3TokensBatch} from './batches/CreditifyV3TokensBatch.sol';
import {CreditifyV3PoolBatch} from './batches/CreditifyV3PoolBatch.sol';
import {CreditifyV3GettersBatchOne} from './batches/CreditifyV3GettersBatchOne.sol';
import {CreditifyV3GettersBatchTwo} from './batches/CreditifyV3GettersBatchTwo.sol';
import {CreditifyV3GettersProcedureTwo} from '../../contracts/procedures/CreditifyV3GettersProcedureTwo.sol';
import {CreditifyV3PeripheryBatch} from './batches/CreditifyV3PeripheryBatch.sol';
import {CreditifyV3SetupBatch} from './batches/CreditifyV3SetupBatch.sol';
import {CreditifyV3HelpersBatchOne} from './batches/CreditifyV3HelpersBatchOne.sol';
import {CreditifyV3HelpersBatchTwo} from './batches/CreditifyV3HelpersBatchTwo.sol';
import {CreditifyV3MiscBatch} from './batches/CreditifyV3MiscBatch.sol';
import '../../interfaces/IMarketReportTypes.sol';
import {IMarketReportStorage} from '../../interfaces/IMarketReportStorage.sol';
import {IPoolReport} from '../../interfaces/IPoolReport.sol';

library CreditifyV3BatchOrchestration {
  struct DeployCreditifyV3Variables {
    CreditifyV3SetupBatch setupBatch;
    InitialReport initialReport;
    CreditifyV3GettersBatchOne.GettersReportBatchOne gettersReport1;
    PoolReport poolReport;
    PeripheryReport peripheryReport;
    MiscReport miscReport;
    SetupReport setupReport;
    CreditifyV3GettersBatchTwo.GettersReportBatchTwo gettersReport2;
    CreditifyV3TokensBatch.TokensReport tokensReport;
    ConfigEngineReport configEngineReport;
    StaticATokenReport staticATokenReport;
    MarketReport report;
  }

  function deployCreditifyV3(
    address deployer,
    Roles memory roles,
    MarketConfig memory config,
    DeployFlags memory flags,
    MarketReport memory deployedContracts
  ) internal returns (MarketReport memory) {
    DeployCreditifyV3Variables memory variables;

    (variables.setupBatch, variables.initialReport) = _deploySetupContract(
      deployer,
      roles,
      config,
      deployedContracts
    );

    variables.gettersReport1 = _deployGettersBatch1(
      config.networkBaseTokenPriceInUsdProxyAggregator,
      config.marketReferenceCurrencyPriceInUsdProxyAggregator
    );

    variables.poolReport = _deployPoolImplementations(
      variables.initialReport.poolAddressesProvider,
      variables.initialReport.interestRateStrategy,
      flags
    );

    variables.peripheryReport = _deployPeripherals(
      roles,
      config,
      variables.initialReport.poolAddressesProvider,
      address(variables.setupBatch)
    );

    variables.miscReport = _deployMisc(
      variables.initialReport.poolAddressesProvider
    );
    variables.miscReport.defaultInterestRateStrategy = variables.initialReport.interestRateStrategy;

    variables.setupReport = variables.setupBatch.setupCreditifyV3Market(
      roles,
      config,
      variables.poolReport.poolImplementation,
      variables.poolReport.poolConfiguratorImplementation,
      variables.peripheryReport.creditifyOracle,
      variables.peripheryReport.rewardsControllerImplementation
    );

    variables.gettersReport2 = _deployGettersBatch2(
      variables.setupReport.poolProxy,
      roles.poolAdmin,
      config.wrappedNativeToken,
      variables.initialReport.poolAddressesProvider
    );

    variables.setupBatch.setProtocolDataProvider(variables.gettersReport2.protocolDataProvider);

    variables.setupBatch.transferMarketOwnership(roles);

    variables.tokensReport = _deployTokens(
      variables.setupReport.poolProxy,
      variables.setupReport.rewardsControllerProxy,
      variables.peripheryReport
    );

    variables.configEngineReport = _deployHelpersBatch1(
      variables.setupReport,
      variables.miscReport,
      variables.peripheryReport,
      variables.tokensReport
    );

    variables.staticATokenReport = _deployHelpersBatch2(
      variables.setupReport.poolProxy,
      variables.setupReport.rewardsControllerProxy,
      roles.poolAdmin
    );

    variables.report = _generateMarketReport(
      variables.initialReport,
      variables.gettersReport1,
      variables.gettersReport2,
      variables.poolReport,
      variables.peripheryReport,
      variables.miscReport,
      variables.setupReport,
      variables.tokensReport,
      variables.configEngineReport,
      variables.staticATokenReport
    );
    variables.setupBatch.setMarketReport(variables.report);

    return variables.report;
  }

  function _deploySetupContract(
    address deployer,
    Roles memory roles,
    MarketConfig memory config,
    MarketReport memory deployedContracts
  ) internal returns (CreditifyV3SetupBatch, InitialReport memory) {
    CreditifyV3SetupBatch setupBatch = new CreditifyV3SetupBatch(deployer, roles, config, deployedContracts);
    return (setupBatch, setupBatch.getInitialReport());
  }

  function _deployGettersBatch1(
    address networkBaseTokenPriceInUsdProxyAggregator,
    address marketReferenceCurrencyPriceInUsdProxyAggregator
  ) internal returns (CreditifyV3GettersBatchOne.GettersReportBatchOne memory) {
    CreditifyV3GettersBatchOne gettersBatch1 = new CreditifyV3GettersBatchOne(
      networkBaseTokenPriceInUsdProxyAggregator,
      marketReferenceCurrencyPriceInUsdProxyAggregator
    );

    return gettersBatch1.getGettersReportOne();
  }

  function _deployGettersBatch2(
    address poolProxy,
    address poolAdmin,
    address wrappedNativeToken,
    address poolAddressesProvider
  ) internal returns (CreditifyV3GettersBatchTwo.GettersReportBatchTwo memory) {
    CreditifyV3GettersBatchTwo gettersBatch2 = new CreditifyV3GettersBatchTwo(
      poolProxy,
      poolAdmin,
      wrappedNativeToken,
      poolAddressesProvider
    );
    CreditifyV3GettersBatchTwo.GettersReportBatchTwo memory gettersReportTwo = gettersBatch2
      .getGettersReportTwo();

    if (wrappedNativeToken != address(0)) {
      return gettersReportTwo;
    }

    return
      CreditifyV3GettersProcedureTwo.GettersReportBatchTwo({
        wrappedTokenGateway: address(0),
        protocolDataProvider: gettersReportTwo.protocolDataProvider
      });
  }

  function _deployHelpersBatch1(
    SetupReport memory setupReport,
    MiscReport memory miscReport,
    PeripheryReport memory peripheryReport,
    CreditifyV3TokensBatch.TokensReport memory tokensReport
  ) internal returns (ConfigEngineReport memory) {
    address treasury = peripheryReport.treasury;
    if (peripheryReport.revenueSplitter != address(0)) {
      treasury = peripheryReport.revenueSplitter;
    }

    CreditifyV3HelpersBatchOne helpersBatchOne = new CreditifyV3HelpersBatchOne(
      setupReport.poolProxy,
      setupReport.poolConfiguratorProxy,
      miscReport.defaultInterestRateStrategy,
      peripheryReport.creditifyOracle,
      setupReport.rewardsControllerProxy,
      treasury,
      tokensReport.aToken,
      tokensReport.variableDebtToken
    );

    return helpersBatchOne.getConfigEngineReport();
  }

  function _deployHelpersBatch2(
    address pool,
    address rewardsController,
    address poolAdmin
  ) internal returns (StaticATokenReport memory) {
    CreditifyV3HelpersBatchTwo helpersBatchTwo = new CreditifyV3HelpersBatchTwo(
      pool,
      rewardsController,
      poolAdmin
    );

    return helpersBatchTwo.staticATokenReport();
  }

  function _deployMisc(
    address poolAddressesProvider
  ) internal returns (MiscReport memory) {
    CreditifyV3MiscBatch miscBatch = new CreditifyV3MiscBatch(
      poolAddressesProvider
    );

    return miscBatch.getMiscReport();
  }

  function _deployPoolImplementations(
    address poolAddressesProvider,
    address interestRateStrategy,
    DeployFlags memory flags
  ) internal returns (PoolReport memory) {
    IPoolReport poolBatch = IPoolReport(new CreditifyV3PoolBatch(poolAddressesProvider, interestRateStrategy));

    return poolBatch.getPoolReport();
  }

  function _deployPeripherals(
    Roles memory roles,
    MarketConfig memory config,
    address poolAddressesProvider,
    address setupBatch
  ) internal returns (PeripheryReport memory) {
    CreditifyV3PeripheryBatch peripheryBatch = new CreditifyV3PeripheryBatch(
      roles.poolAdmin,
      config,
      poolAddressesProvider,
      setupBatch
    );

    return peripheryBatch.getPeripheryReport();
  }

  function _deployTokens(
    address poolProxy,
    address rewardsControllerProxy,
    PeripheryReport memory peripheryReport
  ) internal returns (CreditifyV3TokensBatch.TokensReport memory) {
    address treasury = peripheryReport.treasury;
    if (peripheryReport.revenueSplitter != address(0)) {
      treasury = peripheryReport.revenueSplitter;
    }
    CreditifyV3TokensBatch tokensBatch = new CreditifyV3TokensBatch(
      poolProxy,
      rewardsControllerProxy,
      treasury
    );

    return tokensBatch.getTokensReport();
  }

  function _generateMarketReport(
    InitialReport memory initialReport,
    CreditifyV3GettersBatchOne.GettersReportBatchOne memory gettersReportOne,
    CreditifyV3GettersBatchTwo.GettersReportBatchTwo memory gettersReportTwo,
    PoolReport memory poolReport,
    PeripheryReport memory peripheryReport,
    MiscReport memory miscReport,
    SetupReport memory setupReport,
    CreditifyV3TokensBatch.TokensReport memory tokensReport,
    ConfigEngineReport memory configEngineReport,
    StaticATokenReport memory staticATokenReport
  ) internal pure returns (MarketReport memory) {
    MarketReport memory report;

    report.poolAddressesProvider = initialReport.poolAddressesProvider;
    report.poolAddressesProviderRegistry = initialReport.poolAddressesProviderRegistry;
    report.emissionManager = peripheryReport.emissionManager;
    report.rewardsControllerImplementation = peripheryReport.rewardsControllerImplementation;
    report.walletBalanceProvider = gettersReportOne.walletBalanceProvider;
    report.uiIncentiveDataProvider = gettersReportOne.uiIncentiveDataProvider;
    report.protocolDataProvider = gettersReportTwo.protocolDataProvider;
    report.uiPoolDataProvider = gettersReportOne.uiPoolDataProvider;
    report.poolImplementation = poolReport.poolImplementation;
    report.wrappedTokenGateway = gettersReportTwo.wrappedTokenGateway;
    report.poolConfiguratorImplementation = poolReport.poolConfiguratorImplementation;
    report.creditifyOracle = peripheryReport.creditifyOracle;
    report.treasuryImplementation = peripheryReport.treasuryImplementation;
    report.treasury = peripheryReport.treasury;
    report.dustBin = peripheryReport.dustBin;
    report.emptyImplementation = peripheryReport.emptyImplementation;
    report.poolProxy = setupReport.poolProxy;
    report.poolConfiguratorProxy = setupReport.poolConfiguratorProxy;
    report.rewardsControllerProxy = setupReport.rewardsControllerProxy;
    report.aclManager = setupReport.aclManager;
    report.aToken = tokensReport.aToken;
    report.variableDebtToken = tokensReport.variableDebtToken;
    report.defaultInterestRateStrategy = miscReport.defaultInterestRateStrategy;
    report.configEngine = configEngineReport.configEngine;
    report.staticATokenFactoryImplementation = staticATokenReport.staticATokenFactoryImplementation;
    report.staticATokenFactoryProxy = staticATokenReport.staticATokenFactoryProxy;
    report.staticATokenImplementation = staticATokenReport.staticATokenImplementation;
    report.transparentProxyFactory = staticATokenReport.transparentProxyFactory;
    report.revenueSplitter = peripheryReport.revenueSplitter;

    return report;
  }
}
