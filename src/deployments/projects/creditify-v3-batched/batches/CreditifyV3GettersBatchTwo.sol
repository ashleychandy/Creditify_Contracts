// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3GettersProcedureTwo} from "../../../contracts/procedures/CreditifyV3GettersProcedureTwo.sol";

contract CreditifyV3GettersBatchTwo is CreditifyV3GettersProcedureTwo {
    GettersReportBatchTwo internal _gettersReport;

    constructor(address poolProxy, address poolAdmin, address wrappedNativeToken, address poolAddressesProvider) {
        _gettersReport =
            _deployCreditifyV3GettersBatchTwo(poolProxy, poolAdmin, wrappedNativeToken, poolAddressesProvider);
    }

    function getGettersReportTwo() external view returns (GettersReportBatchTwo memory) {
        return _gettersReport;
    }
}
