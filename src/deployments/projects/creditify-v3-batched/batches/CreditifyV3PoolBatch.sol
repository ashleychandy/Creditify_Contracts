// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3PoolProcedure} from '../../../contracts/procedures/CreditifyV3PoolProcedure.sol';
import {IPoolReport} from '../../../interfaces/IPoolReport.sol';

import '../../../interfaces/IMarketReportTypes.sol';

contract CreditifyV3PoolBatch is CreditifyV3PoolProcedure, IPoolReport {
  PoolReport internal _poolReport;

  constructor(address poolAddressesProvider, address interestRateStrategy) {
    _poolReport = _deployCreditifyV3Pool(poolAddressesProvider, interestRateStrategy);
  }

  function getPoolReport() external view returns (PoolReport memory) {
    return _poolReport;
  }
}
