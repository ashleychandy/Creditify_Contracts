// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3HelpersProcedureOne} from "../../../contracts/procedures/CreditifyV3HelpersProcedureOne.sol";
import "../../../interfaces/IMarketReportTypes.sol";

contract CreditifyV3HelpersBatchOne is CreditifyV3HelpersProcedureOne {
    ConfigEngineReport internal _report;

    constructor(
        address poolProxy,
        address poolConfiguratorProxy,
        address defaultInterestRateStrategy,
        address creditifyOracle,
        address rewardsController,
        address collector,
        address aTokenImpl,
        address vTokenImpl
    ) {
        _report = _deployConfigEngine(
            poolProxy,
            poolConfiguratorProxy,
            defaultInterestRateStrategy,
            creditifyOracle,
            rewardsController,
            collector,
            aTokenImpl,
            vTokenImpl
        );
    }

    function getConfigEngineReport() external view returns (ConfigEngineReport memory) {
        return _report;
    }
}
