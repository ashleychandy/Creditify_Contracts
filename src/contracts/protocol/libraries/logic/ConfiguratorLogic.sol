// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPool} from '../../../interfaces/IPool.sol';
import {IPoolConfigurator} from '../../../interfaces/IPoolConfigurator.sol';
import {IInitializableAToken} from '../../../interfaces/IInitializableAToken.sol';
import {IInitializableDebtToken} from '../../../interfaces/IInitializableDebtToken.sol';
import {InitializableImmutableAdminUpgradeabilityProxy} from '../../../misc/creditify-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol';
import {IReserveInterestRateStrategy} from '../../../interfaces/IReserveInterestRateStrategy.sol';
import {ReserveConfiguration} from '../configuration/ReserveConfiguration.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {Errors} from '../helpers/Errors.sol';
import {ConfiguratorInputTypes} from '../types/ConfiguratorInputTypes.sol';
import {IERC20Detailed} from '../../../dependencies/openzeppelin/contracts/IERC20Detailed.sol';

library ConfiguratorLogic {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function executeInitReserve(
    IPool pool,
    ConfiguratorInputTypes.InitReserveInput calldata input
  ) external {
    
    uint8 underlyingAssetDecimals = IERC20Detailed(input.underlyingAsset).decimals();
    require(underlyingAssetDecimals > 5, Errors.InvalidDecimals());

    address aTokenProxyAddress = _initTokenWithProxy(
      input.aTokenImpl,
      abi.encodeWithSelector(
        IInitializableAToken.initialize.selector,
        pool,
        input.underlyingAsset,
        underlyingAssetDecimals,
        input.aTokenName,
        input.aTokenSymbol,
        input.params
      )
    );

    address variableDebtTokenProxyAddress = _initTokenWithProxy(
      input.variableDebtTokenImpl,
      abi.encodeWithSelector(
        IInitializableDebtToken.initialize.selector,
        pool,
        input.underlyingAsset,
        underlyingAssetDecimals,
        input.variableDebtTokenName,
        input.variableDebtTokenSymbol,
        input.params
      )
    );

    pool.initReserve(input.underlyingAsset, aTokenProxyAddress, variableDebtTokenProxyAddress);

    DataTypes.ReserveConfigurationMap memory currentConfig = DataTypes.ReserveConfigurationMap(0);

    currentConfig.setDecimals(underlyingAssetDecimals);

    currentConfig.setActive(true);
    currentConfig.setPaused(false);
    currentConfig.setFrozen(false);
    currentConfig.setVirtualAccActive();

    pool.setConfiguration(input.underlyingAsset, currentConfig);

    address interestRateStrategyAddress = pool.RESERVE_INTEREST_RATE_STRATEGY();
    IReserveInterestRateStrategy(interestRateStrategyAddress).setInterestRateParams(
      input.underlyingAsset,
      input.interestRateData
    );

    emit IPoolConfigurator.ReserveInitialized(
      input.underlyingAsset,
      aTokenProxyAddress,
      address(0),
      variableDebtTokenProxyAddress,
      interestRateStrategyAddress
    );
  }

  function executeUpdateAToken(
    IPool cachedPool,
    ConfiguratorInputTypes.UpdateATokenInput calldata input
  ) external {
    address aTokenAddress = cachedPool.getReserveAToken(input.asset);

    uint256 decimals = cachedPool.getConfiguration(input.asset).getDecimals();

    bytes memory encodedCall = abi.encodeWithSelector(
      IInitializableAToken.initialize.selector,
      cachedPool,
      input.asset,
      decimals,
      input.name,
      input.symbol,
      input.params
    );

    _upgradeTokenImplementation(aTokenAddress, input.implementation, encodedCall);

    emit IPoolConfigurator.ATokenUpgraded(input.asset, aTokenAddress, input.implementation);
  }

  function executeUpdateVariableDebtToken(
    IPool cachedPool,
    ConfiguratorInputTypes.UpdateDebtTokenInput calldata input
  ) external {
    address variableDebtTokenAddress = cachedPool.getReserveVariableDebtToken(input.asset);

    uint256 decimals = cachedPool.getConfiguration(input.asset).getDecimals();

    bytes memory encodedCall = abi.encodeWithSelector(
      IInitializableDebtToken.initialize.selector,
      cachedPool,
      input.asset,
      decimals,
      input.name,
      input.symbol,
      input.params
    );

    _upgradeTokenImplementation(variableDebtTokenAddress, input.implementation, encodedCall);

    emit IPoolConfigurator.VariableDebtTokenUpgraded(
      input.asset,
      variableDebtTokenAddress,
      input.implementation
    );
  }

  function _initTokenWithProxy(
    address implementation,
    bytes memory initParams
  ) internal returns (address) {
    InitializableImmutableAdminUpgradeabilityProxy proxy = new InitializableImmutableAdminUpgradeabilityProxy(
        address(this)
      );

    proxy.initialize(implementation, initParams);

    return address(proxy);
  }

  function _upgradeTokenImplementation(
    address proxyAddress,
    address implementation,
    bytes memory initParams
  ) internal {
    InitializableImmutableAdminUpgradeabilityProxy proxy = InitializableImmutableAdminUpgradeabilityProxy(
        payable(proxyAddress)
      );

    proxy.upgradeToAndCall(implementation, initParams);
  }
}
