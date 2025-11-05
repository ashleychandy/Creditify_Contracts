// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3GettersProcedureOne} from '../../../contracts/procedures/CreditifyV3GettersProcedureOne.sol';

contract CreditifyV3GettersBatchOne is CreditifyV3GettersProcedureOne {
  GettersReportBatchOne internal _gettersReport;

  constructor(
    address networkBaseTokenPriceInUsdProxyAggregator,
    address marketReferenceCurrencyPriceInUsdProxyAggregator
  ) {
    _gettersReport = _deployCreditifyV3GettersBatchOne(
      networkBaseTokenPriceInUsdProxyAggregator,
      marketReferenceCurrencyPriceInUsdProxyAggregator
    );
  }

  function getGettersReportOne() external view returns (GettersReportBatchOne memory) {
    return _gettersReport;
  }
}
