// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../interfaces/IMarketReportTypes.sol';
import {CreditifyOracle} from '../../../contracts/misc/CreditifyOracle.sol';

contract CreditifyV3OracleProcedure {
  function _deployCreditifyOracle(
    uint16 oracleDecimals,
    address poolAddressesProvider
  ) internal returns (address) {
    address[] memory emptyArray;

    address creditifyOracle = address(
      new CreditifyOracle(
        IPoolAddressesProvider(poolAddressesProvider),
        emptyArray,
        emptyArray,
        address(0),
        address(0),
        10 ** oracleDecimals
      )
    );

    return creditifyOracle;
  }
}
