// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WalletBalanceProvider} from "../../../contracts/helpers/WalletBalanceProvider.sol";
import {UiPoolDataProviderV3} from "../../../contracts/helpers/UiPoolDataProviderV3.sol";
import {UiIncentiveDataProviderV3} from "../../../contracts/helpers/UiIncentiveDataProviderV3.sol";
import {AggregatorInterface} from "../../../contracts/dependencies/chainlink/AggregatorInterface.sol";
import {CreditifyProtocolDataProvider} from "../../../contracts/helpers/CreditifyProtocolDataProvider.sol";
import {IPoolAddressesProvider} from "../../../contracts/interfaces/IPoolAddressesProvider.sol";

contract CreditifyV3GettersProcedureOne {
    struct GettersReportBatchOne {
        address walletBalanceProvider;
        address uiIncentiveDataProvider;
        address uiPoolDataProvider;
    }

    function _deployCreditifyV3GettersBatchOne(
        address networkBaseTokenPriceInUsdProxyAggregator,
        address marketReferenceCurrencyPriceInUsdProxyAggregator
    ) internal returns (GettersReportBatchOne memory) {
        GettersReportBatchOne memory report;

        report.walletBalanceProvider = address(new WalletBalanceProvider());
        report.uiIncentiveDataProvider = address(new UiIncentiveDataProviderV3());

        if (
            networkBaseTokenPriceInUsdProxyAggregator != address(0)
                && marketReferenceCurrencyPriceInUsdProxyAggregator != address(0)
        ) {
            report.uiPoolDataProvider = address(
                new UiPoolDataProviderV3(
                    AggregatorInterface(networkBaseTokenPriceInUsdProxyAggregator),
                    AggregatorInterface(marketReferenceCurrencyPriceInUsdProxyAggregator)
                )
            );
        }

        return report;
    }
}
