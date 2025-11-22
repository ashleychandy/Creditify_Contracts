// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from "../protocol/libraries/types/DataTypes.sol";

interface IReserveInterestRateStrategy {
    function setInterestRateParams(address reserve, bytes calldata rateData) external;

    function calculateInterestRates(DataTypes.CalculateInterestRatesParams memory params)
        external
        view
        returns (uint256, uint256);
}
