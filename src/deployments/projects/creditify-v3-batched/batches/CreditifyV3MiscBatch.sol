// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3MiscProcedure} from '../../../contracts/procedures/CreditifyV3MiscProcedure.sol';
import '../../../interfaces/IMarketReportTypes.sol';

contract CreditifyV3MiscBatch is CreditifyV3MiscProcedure {
  MiscReport internal _report;

  constructor(address poolAddressesProvider) {
    MiscReport memory miscReport = _deployDefaultIR(poolAddressesProvider);
    _report.defaultInterestRateStrategy = miscReport.defaultInterestRateStrategy;
  }

  function getMiscReport() external view returns (MiscReport memory) {
    return _report;
  }
}
