// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Create2Utils} from '../utilities/Create2Utils.sol';
import {ConfigEngineReport} from '../../interfaces/IMarketReportTypes.sol';
import {CreditifyV3ConfigEngine, ICreditifyV3ConfigEngine, CapsEngine, BorrowEngine, CollateralEngine, RateEngine, PriceFeedEngine, ListingEngine} from '../../../contracts/extensions/v3-config-engine/CreditifyV3ConfigEngine.sol';
import {IPool} from '../../../contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from '../../../contracts/interfaces/IPoolConfigurator.sol';
import {ICreditifyOracle} from '../../../contracts/interfaces/ICreditifyOracle.sol';

contract CreditifyV3HelpersProcedureOne {
  function _deployConfigEngine(
    address pool,
    address poolConfigurator,
    address defaultInterestRateStrategy,
    address creditifyOracle,
    address rewardsController,
    address collector,
    address aTokenImpl,
    address vTokenImpl
  ) internal returns (ConfigEngineReport memory configEngineReport) {
    ICreditifyV3ConfigEngine.EngineLibraries memory engineLibraries = ICreditifyV3ConfigEngine
      .EngineLibraries({
        listingEngine: Create2Utils._create2Deploy('v1', type(ListingEngine).creationCode),
        borrowEngine: Create2Utils._create2Deploy('v1', type(BorrowEngine).creationCode),
        collateralEngine: Create2Utils._create2Deploy('v1', type(CollateralEngine).creationCode),
        priceFeedEngine: Create2Utils._create2Deploy('v1', type(PriceFeedEngine).creationCode),
        rateEngine: Create2Utils._create2Deploy('v1', type(RateEngine).creationCode),
        capsEngine: Create2Utils._create2Deploy('v1', type(CapsEngine).creationCode)
      });

    ICreditifyV3ConfigEngine.EngineConstants memory engineConstants = ICreditifyV3ConfigEngine
      .EngineConstants({
        pool: IPool(pool),
        poolConfigurator: IPoolConfigurator(poolConfigurator),
        defaultInterestRateStrategy: defaultInterestRateStrategy,
        oracle: ICreditifyOracle(creditifyOracle),
        rewardsController: rewardsController,
        collector: collector
      });

    configEngineReport.listingEngine = engineLibraries.listingEngine;
    configEngineReport.borrowEngine = engineLibraries.borrowEngine;
    configEngineReport.collateralEngine = engineLibraries.collateralEngine;
    configEngineReport.priceFeedEngine = engineLibraries.priceFeedEngine;
    configEngineReport.rateEngine = engineLibraries.rateEngine;
    configEngineReport.capsEngine = engineLibraries.capsEngine;

    configEngineReport.configEngine = address(
      new CreditifyV3ConfigEngine(aTokenImpl, vTokenImpl, engineConstants, engineLibraries)
    );
    return configEngineReport;
  }
}
