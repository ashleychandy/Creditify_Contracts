// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';

contract DefaultMarketInput is MarketInput {
  function _getMarketInput(
    address deployer
  )
    internal
    pure
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

    config.marketId = 'Creditify V3 Testnet Market';
    config.providerId = 8080;
    config.oracleDecimals = 8;

    // Oracle configurations - deployed oracle contracts (normalized to 8 decimals)
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x0dd7Ee05ee4924caE638bDc2f203CB771973E09C; // XDC/USD Oracle
    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x02F95E0dCaB1fF62DB3424FfEeBbf521B1Bb9d01; // USDC/USD Oracle

    // Wrapped native token - XDC wrapped token
    config.wrappedNativeToken = 0xC2EABDC14A96A48ee56Dec9917d9057AB93439Ab; // WXDC_APOTHEM from .env

    // Optional configurations (can be left as zero addresses for testnet)
    config.incentivesProxy = address(0);
    config.treasury = address(0);
    config.treasuryPartner = address(0);
    config.treasurySplitPercent = 0;

    return (roles, config, flags, deployedContracts);
  }
}
