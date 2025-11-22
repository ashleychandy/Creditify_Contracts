// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketInput.sol";

contract DefaultMarketInput is MarketInput {
    // Addresses to be set from environment variables
    address internal xdcUsdOracle;
    address internal usdcUsdOracle;
    address internal wrappedXdc;

    // Constructor with optional parameters (defaults to zero addresses for tests)
    constructor(address _xdcUsdOracle, address _usdcUsdOracle, address _wrappedXdc) {
        xdcUsdOracle = _xdcUsdOracle;
        usdcUsdOracle = _usdcUsdOracle;
        wrappedXdc = _wrappedXdc;
    }

    // Setter functions to allow tests to configure addresses after construction
    function _setXdcUsdOracle(address _oracle) internal {
        xdcUsdOracle = _oracle;
    }

    function _setUsdcUsdOracle(address _oracle) internal {
        usdcUsdOracle = _oracle;
    }

    function _setWrappedXdc(address _wrappedXdc) internal {
        wrappedXdc = _wrappedXdc;
    }

    function _getMarketInput(address deployer)
        internal
        view
        override
        returns (
            Roles memory roles,
            MarketConfig memory config,
            DeployFlags memory flags,
            MarketReport memory deployedContracts
        )
    {
        roles.marketOwner = deployer;
        roles.emergencyAdmin = deployer;
        roles.poolAdmin = deployer;

        config.marketId = "Creditify V3 Market";
        config.providerId = 1;
        config.oracleDecimals = 8;

        // Oracle configurations - read from constructor parameters (set from .env)
        config.networkBaseTokenPriceInUsdProxyAggregator = xdcUsdOracle;
        config.marketReferenceCurrencyPriceInUsdProxyAggregator = usdcUsdOracle;

        // Wrapped native token - read from constructor parameter (set from .env)
        config.wrappedNativeToken = wrappedXdc;

        // Optional configurations (can be left as zero addresses for testnet)
        config.incentivesProxy = address(0);
        config.treasury = address(0);
        config.treasuryPartner = address(0);
        config.treasurySplitPercent = 0;

        return (roles, config, flags, deployedContracts);
    }
}
