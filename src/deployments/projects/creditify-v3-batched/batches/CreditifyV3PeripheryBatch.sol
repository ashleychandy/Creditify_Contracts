// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3TreasuryProcedure} from '../../../contracts/procedures/CreditifyV3TreasuryProcedure.sol';
import {CreditifyV3OracleProcedure} from '../../../contracts/procedures/CreditifyV3OracleProcedure.sol';
import {CreditifyV3IncentiveProcedure} from '../../../contracts/procedures/CreditifyV3IncentiveProcedure.sol';
import {CreditifyV3DefaultRateStrategyProcedure} from '../../../contracts/procedures/CreditifyV3DefaultRateStrategyProcedure.sol';
import {Ownable} from '../../../../contracts/dependencies/openzeppelin/contracts/Ownable.sol';
import '../../../interfaces/IMarketReportTypes.sol';
import {IRewardsController} from '../../../../contracts/rewards/interfaces/IRewardsController.sol';
import {RevenueSplitter} from '../../../../contracts/treasury/RevenueSplitter.sol';

contract CreditifyV3PeripheryBatch is
  CreditifyV3TreasuryProcedure,
  CreditifyV3OracleProcedure,
  CreditifyV3IncentiveProcedure
{
  PeripheryReport internal _report;

  constructor(
    address poolAdmin,
    MarketConfig memory config,
    address poolAddressesProvider,
    address setupBatch
  ) {
    _report.creditifyOracle = _deployCreditifyOracle(config.oracleDecimals, poolAddressesProvider);

    if (config.treasury == address(0)) {
      TreasuryReport memory treasuryReport = _deployCreditifyV3Treasury(poolAdmin, config.salt);

      _report.treasury = treasuryReport.treasury;
      _report.treasuryImplementation = treasuryReport.treasuryImplementation;

      _report.dustBin = treasuryReport.dustBin;
      _report.emptyImplementation = treasuryReport.emptyImplementation;
    } else {
      _report.treasury = config.treasury;
    }

    if (
      config.treasuryPartner != address(0) &&
      config.treasurySplitPercent > 0 &&
      config.treasurySplitPercent < 100_00
    ) {
      _report.revenueSplitter = address(
        new RevenueSplitter(_report.treasury, config.treasuryPartner, config.treasurySplitPercent)
      );
    }

    if (config.incentivesProxy == address(0)) {
      (_report.emissionManager, _report.rewardsControllerImplementation) = _deployIncentives(
        setupBatch
      );
    } else {
      _report.emissionManager = IRewardsController(config.incentivesProxy).getEmissionManager();
    }
  }

  function getPeripheryReport() external view returns (PeripheryReport memory) {
    return _report;
  }
}
