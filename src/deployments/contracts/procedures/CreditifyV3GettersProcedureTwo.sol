// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPool} from "../../../contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "../../../contracts/interfaces/IPoolAddressesProvider.sol";
import {WrappedTokenGatewayV3} from "../../../contracts/helpers/WrappedTokenGatewayV3.sol";
import {CreditifyProtocolDataProvider} from "../../../contracts/helpers/CreditifyProtocolDataProvider.sol";
import {LiquidationDataProvider} from "../../../contracts/helpers/LiquidationDataProvider.sol";

contract CreditifyV3GettersProcedureTwo {
    struct GettersReportBatchTwo {
        address wrappedTokenGateway;
        address protocolDataProvider;
        address liquidationDataProvider;
    }

    function _deployCreditifyV3GettersBatchTwo(
        address poolProxy,
        address poolAdmin,
        address wrappedNativeToken,
        address poolAddressesProvider
    ) internal returns (GettersReportBatchTwo memory) {
        GettersReportBatchTwo memory report;

        if (wrappedNativeToken != address(0)) {
            report.wrappedTokenGateway =
                address(new WrappedTokenGatewayV3(wrappedNativeToken, poolAdmin, IPool(poolProxy)));
        }

        report.protocolDataProvider =
            address(new CreditifyProtocolDataProvider(IPoolAddressesProvider(poolAddressesProvider)));

        report.liquidationDataProvider = address(new LiquidationDataProvider(poolProxy, poolAddressesProvider));

        return report;
    }
}
