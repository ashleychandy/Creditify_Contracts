// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {VersionedInitializable} from '../../misc/creditify-upgradeability/VersionedInitializable.sol';
import {ReserveConfiguration} from '../libraries/configuration/ReserveConfiguration.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {IDefaultInterestRateStrategyV2} from '../../interfaces/IDefaultInterestRateStrategyV2.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {ConfiguratorLogic} from '../libraries/logic/ConfiguratorLogic.sol';
import {ConfiguratorInputTypes} from '../libraries/types/ConfiguratorInputTypes.sol';
import {IPoolConfigurator} from '../../interfaces/IPoolConfigurator.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IPoolDataProvider} from '../../interfaces/IPoolDataProvider.sol';

abstract contract PoolConfigurator is VersionedInitializable, IPoolConfigurator {
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IPoolAddressesProvider internal _addressesProvider;
  IPool internal _pool;

  mapping(address => uint256) internal _pendingLtv;

  uint40 public constant MAX_GRACE_PERIOD = 4 hours;

  modifier onlyPoolAdmin() {
    _onlyPoolAdmin();
    _;
  }

  modifier onlyEmergencyOrPoolAdmin() {
    _onlyPoolOrEmergencyAdmin();
    _;
  }

  modifier onlyAssetListingOrPoolAdmins() {
    _onlyAssetListingOrPoolAdmins();
    _;
  }

  modifier onlyRiskOrPoolAdmins() {
    _onlyRiskOrPoolAdmins();
    _;
  }

  modifier onlyRiskOrPoolOrEmergencyAdmins() {
    _onlyRiskOrPoolOrEmergencyAdmins();
    _;
  }

  function initialize(IPoolAddressesProvider provider) public virtual;

  function initReserves(
    ConfiguratorInputTypes.InitReserveInput[] calldata input
  ) external override onlyAssetListingOrPoolAdmins {
    IPool cachedPool = _pool;

    address interestRateStrategyAddress = cachedPool.RESERVE_INTEREST_RATE_STRATEGY();
    for (uint256 i = 0; i < input.length; i++) {
      ConfiguratorLogic.executeInitReserve(cachedPool, input[i]);

      emit ReserveInterestRateDataChanged(
        input[i].underlyingAsset,
        interestRateStrategyAddress,
        input[i].interestRateData
      );
    }
  }

  function dropReserve(address asset) external override onlyPoolAdmin {
    _pool.dropReserve(asset);
    emit ReserveDropped(asset);
  }

  function updateAToken(
    ConfiguratorInputTypes.UpdateATokenInput calldata input
  ) external override onlyPoolAdmin {
    ConfiguratorLogic.executeUpdateAToken(_pool, input);
  }

  function updateVariableDebtToken(
    ConfiguratorInputTypes.UpdateDebtTokenInput calldata input
  ) external override onlyPoolAdmin {
    ConfiguratorLogic.executeUpdateVariableDebtToken(_pool, input);
  }

  function setReserveBorrowing(address asset, bool enabled) external override onlyRiskOrPoolAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    currentConfig.setBorrowingEnabled(enabled);
    _pool.setConfiguration(asset, currentConfig);
    emit ReserveBorrowing(asset, enabled);
  }

  function configureReserveAsCollateral(
    address asset,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus
  ) external override onlyRiskOrPoolAdmins {

    require(ltv <= liquidationThreshold, Errors.InvalidReserveParams());

    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);

    if (liquidationThreshold != 0) {

      require(liquidationBonus > PercentageMath.PERCENTAGE_FACTOR, Errors.InvalidReserveParams());

      require(
        liquidationThreshold.percentMul(liquidationBonus) <= PercentageMath.PERCENTAGE_FACTOR,
        Errors.InvalidReserveParams()
      );
    } else {
      require(liquidationBonus == 0, Errors.InvalidReserveParams());

      _checkNoSuppliers(asset);
    }

    uint256 newLtv = ltv;

    if (currentConfig.getFrozen()) {
      _pendingLtv[asset] = ltv;
      newLtv = 0;

      emit PendingLtvChanged(asset, ltv);
    } else {
      currentConfig.setLtv(ltv);
    }

    currentConfig.setLiquidationThreshold(liquidationThreshold);
    currentConfig.setLiquidationBonus(liquidationBonus);

    _pool.setConfiguration(asset, currentConfig);

    emit CollateralConfigurationChanged(asset, newLtv, liquidationThreshold, liquidationBonus);
  }

  function setReserveActive(address asset, bool active) external override onlyPoolAdmin {
    if (!active) _checkNoSuppliers(asset);
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    currentConfig.setActive(active);
    _pool.setConfiguration(asset, currentConfig);
    emit ReserveActive(asset, active);
  }

  function setReserveFreeze(
    address asset,
    bool freeze
  ) external override onlyRiskOrPoolOrEmergencyAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);

    require(freeze != currentConfig.getFrozen(), Errors.InvalidFreezeState());

    currentConfig.setFrozen(freeze);

    uint256 ltvSet;
    uint256 pendingLtvSet;

    if (freeze) {
      pendingLtvSet = currentConfig.getLtv();
      _pendingLtv[asset] = pendingLtvSet;
      currentConfig.setLtv(0);
    } else {
      ltvSet = _pendingLtv[asset];
      currentConfig.setLtv(ltvSet);
      delete _pendingLtv[asset];
    }

    emit PendingLtvChanged(asset, pendingLtvSet);
    emit CollateralConfigurationChanged(
      asset,
      ltvSet,
      currentConfig.getLiquidationThreshold(),
      currentConfig.getLiquidationBonus()
    );

    _pool.setConfiguration(asset, currentConfig);
    emit ReserveFrozen(asset, freeze);
  }

  function setReservePause(
    address asset,
    bool paused,
    uint40 gracePeriod
  ) public override onlyEmergencyOrPoolAdmin {
    if (!paused && gracePeriod != 0) {
      require(gracePeriod <= MAX_GRACE_PERIOD, Errors.InvalidGracePeriod());

      uint40 until = uint40(block.timestamp) + gracePeriod;
      _pool.setLiquidationGracePeriod(asset, until);
      emit LiquidationGracePeriodChanged(asset, until);
    }

    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    currentConfig.setPaused(paused);
    _pool.setConfiguration(asset, currentConfig);
    emit ReservePaused(asset, paused);
  }

  function setReservePause(address asset, bool paused) external override onlyEmergencyOrPoolAdmin {
    setReservePause(asset, paused, 0);
  }

  function disableLiquidationGracePeriod(address asset) external override onlyEmergencyOrPoolAdmin {
    
    _pool.setLiquidationGracePeriod(asset, 0);

    emit LiquidationGracePeriodDisabled(asset);
  }

  function setReserveFactor(
    address asset,
    uint256 newReserveFactor
  ) external override onlyRiskOrPoolAdmins {
    require(newReserveFactor <= PercentageMath.PERCENTAGE_FACTOR, Errors.InvalidReserveFactor());

    _pool.syncIndexesState(asset);

    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldReserveFactor = currentConfig.getReserveFactor();
    currentConfig.setReserveFactor(newReserveFactor);
    _pool.setConfiguration(asset, currentConfig);
    emit ReserveFactorChanged(asset, oldReserveFactor, newReserveFactor);

    _pool.syncRatesState(asset);
  }

  function setBorrowCap(
    address asset,
    uint256 newBorrowCap
  ) external override onlyRiskOrPoolAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldBorrowCap = currentConfig.getBorrowCap();
    currentConfig.setBorrowCap(newBorrowCap);
    _pool.setConfiguration(asset, currentConfig);
    emit BorrowCapChanged(asset, oldBorrowCap, newBorrowCap);
  }

  function setSupplyCap(
    address asset,
    uint256 newSupplyCap
  ) external override onlyRiskOrPoolAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldSupplyCap = currentConfig.getSupplyCap();
    currentConfig.setSupplyCap(newSupplyCap);
    _pool.setConfiguration(asset, currentConfig);
    emit SupplyCapChanged(asset, oldSupplyCap, newSupplyCap);
  }

  function setLiquidationProtocolFee(
    address asset,
    uint256 newFee
  ) external override onlyRiskOrPoolAdmins {
    require(newFee <= PercentageMath.PERCENTAGE_FACTOR, Errors.InvalidLiquidationProtocolFee());
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldFee = currentConfig.getLiquidationProtocolFee();
    currentConfig.setLiquidationProtocolFee(newFee);
    _pool.setConfiguration(asset, currentConfig);
    emit LiquidationProtocolFeeChanged(asset, oldFee, newFee);
  }

  function setReserveInterestRateData(
    address asset,
    bytes calldata rateData
  ) external onlyRiskOrPoolAdmins {
    _pool.syncIndexesState(asset);

    address interestRateStrategyAddress = _pool.RESERVE_INTEREST_RATE_STRATEGY();
    IDefaultInterestRateStrategyV2(interestRateStrategyAddress).setInterestRateParams(
      asset,
      rateData
    );
    emit ReserveInterestRateDataChanged(asset, interestRateStrategyAddress, rateData);

    _pool.syncRatesState(asset);
  }

  function setPoolPause(bool paused, uint40 gracePeriod) public override onlyEmergencyOrPoolAdmin {
    address[] memory reserves = _pool.getReservesList();

    for (uint256 i = 0; i < reserves.length; i++) {
      if (reserves[i] != address(0)) {
        setReservePause(reserves[i], paused, gracePeriod);
      }
    }
  }

  function setPoolPause(bool paused) external override onlyEmergencyOrPoolAdmin {
    setPoolPause(paused, 0);
  }

  function getPendingLtv(address asset) external view override returns (uint256) {
    return _pendingLtv[asset];
  }

  function getConfiguratorLogic() external pure returns (address) {
    return address(ConfiguratorLogic);
  }

  function _checkNoSuppliers(address asset) internal view {
    DataTypes.ReserveDataLegacy memory reserveData = _pool.getReserveData(asset);
    uint256 totalSupplied = IPoolDataProvider(_addressesProvider.getPoolDataProvider())
      .getATokenTotalSupply(asset);

    require(
      totalSupplied == 0 && reserveData.accruedToTreasury == 0,
      Errors.ReserveLiquidityNotZero()
    );
  }

  function _checkNoBorrowers(address asset) internal view {
    uint256 totalDebt = IPoolDataProvider(_addressesProvider.getPoolDataProvider()).getTotalDebt(
      asset
    );
    require(totalDebt == 0, Errors.ReserveDebtNotZero());
  }

  function _onlyPoolAdmin() internal view {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(aclManager.isPoolAdmin(msg.sender), Errors.CallerNotPoolAdmin());
  }

  function _onlyPoolOrEmergencyAdmin() internal view {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(
      aclManager.isPoolAdmin(msg.sender) || aclManager.isEmergencyAdmin(msg.sender),
      Errors.CallerNotPoolOrEmergencyAdmin()
    );
  }

  function _onlyAssetListingOrPoolAdmins() internal view {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(
      aclManager.isAssetListingAdmin(msg.sender) || aclManager.isPoolAdmin(msg.sender),
      Errors.CallerNotAssetListingOrPoolAdmin()
    );
  }

  function _onlyRiskOrPoolAdmins() internal view {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(
      aclManager.isRiskAdmin(msg.sender) || aclManager.isPoolAdmin(msg.sender),
      Errors.CallerNotRiskOrPoolAdmin()
    );
  }

  function _onlyRiskOrPoolOrEmergencyAdmins() internal view {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(
      aclManager.isRiskAdmin(msg.sender) ||
        aclManager.isPoolAdmin(msg.sender) ||
        aclManager.isEmergencyAdmin(msg.sender),
      Errors.CallerNotRiskOrPoolOrEmergencyAdmin()
    );
  }
}
