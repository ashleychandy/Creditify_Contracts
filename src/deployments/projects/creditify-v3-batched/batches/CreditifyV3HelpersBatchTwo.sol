// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3HelpersProcedureTwo} from '../../../contracts/procedures/CreditifyV3HelpersProcedureTwo.sol';
import '../../../interfaces/IMarketReportTypes.sol';

contract CreditifyV3HelpersBatchTwo is CreditifyV3HelpersProcedureTwo {
  StaticATokenReport internal _report;

  constructor(address pool, address rewardsController, address poolAdmin) {
    _report = _deployStaticAToken(pool, rewardsController, poolAdmin);
  }

  function staticATokenReport() external view returns (StaticATokenReport memory) {
    return _report;
  }
}
