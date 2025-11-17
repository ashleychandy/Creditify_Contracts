// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC4626Upgradeable, Math, IERC4626} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IPool, IPoolAddressesProvider} from '../../interfaces/IPool.sol';
import {ICreditifyOracle} from '../../interfaces/ICreditifyOracle.sol';
import {DataTypes, ReserveConfiguration} from '../../protocol/libraries/configuration/ReserveConfiguration.sol';

import {IAToken} from './interfaces/IAToken.sol';
import {IERC4626StataToken} from './interfaces/IERC4626StataToken.sol';

abstract contract ERC4626StataTokenUpgradeable is ERC4626Upgradeable, IERC4626StataToken {
  using Math for uint256;

  struct ERC4626StataTokenStorage {
    IERC20 _aToken;
  }

  bytes32 private constant ERC4626StataTokenStorageLocation =
    0x983310fea9f3491b0c8a2a87320408ea57c39524710712ae49e40f9510df9300;

  function _getERC4626StataTokenStorage()
    private
    pure
    returns (ERC4626StataTokenStorage storage $)
  {
    assembly {
      $.slot := ERC4626StataTokenStorageLocation
    }
  }

  uint256 public constant RAY = 1e27;

  IPool public immutable POOL;
  IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;

  constructor(IPool pool) {
    POOL = pool;
    POOL_ADDRESSES_PROVIDER = pool.ADDRESSES_PROVIDER();
  }

  function __ERC4626StataToken_init(address newAToken) internal onlyInitializing {
    IERC20 aTokenUnderlying = __ERC4626StataToken_init_unchained(newAToken);
    __ERC4626_init_unchained(aTokenUnderlying);
  }

  function __ERC4626StataToken_init_unchained(
    address newAToken
  ) internal onlyInitializing returns (IERC20) {
    address poolOfAToken = IAToken(newAToken).POOL();
    if (poolOfAToken != address(POOL)) revert PoolAddressMismatch(poolOfAToken);

    IERC20 aTokenUnderlying = IERC20(IAToken(newAToken).UNDERLYING_ASSET_ADDRESS());

    ERC4626StataTokenStorage storage $ = _getERC4626StataTokenStorage();
    $._aToken = IERC20(newAToken);

    SafeERC20.forceApprove(aTokenUnderlying, address(POOL), type(uint256).max);

    return aTokenUnderlying;
  }

  function depositATokens(uint256 assets, address receiver) external returns (uint256) {
    uint256 actualUserBalance = IERC20(aToken()).balanceOf(_msgSender());
    if (assets > actualUserBalance) {
      assets = actualUserBalance;
    }

    uint256 shares = previewDeposit(assets);
    _deposit(_msgSender(), receiver, assets, shares, false);

    return shares;
  }

  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    SignatureParams memory sig,
    bool depositToCreditify
  ) external returns (uint256) {
    address assetToDeposit = depositToCreditify ? asset() : aToken();

    try
      IERC20Permit(assetToDeposit).permit(
        _msgSender(),
        address(this),
        assets,
        deadline,
        sig.v,
        sig.r,
        sig.s
      )
    {} catch {}

    uint256 actualUserBalance = IERC20(assetToDeposit).balanceOf(_msgSender());
    if (assets > actualUserBalance) {
      assets = actualUserBalance;
    }

    uint256 shares = previewDeposit(assets);
    _deposit(_msgSender(), receiver, assets, shares, depositToCreditify);
    return shares;
  }

  function redeemATokens(
    uint256 shares,
    address receiver,
    address owner
  ) external returns (uint256) {
    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner, assets, shares, false);

    return assets;
  }

  function aToken() public view returns (address) {
    ERC4626StataTokenStorage storage $ = _getERC4626StataTokenStorage();
    return address($._aToken);
  }

  function maxMint(address) public view override returns (uint256) {
    uint256 assets = maxDeposit(address(0));
    if (assets == type(uint256).max) return type(uint256).max;
    return convertToShares(assets);
  }

  function maxWithdraw(address owner) public view override returns (uint256) {
    return convertToAssets(maxRedeem(owner));
  }

  function totalAssets() public view override returns (uint256) {
    return _convertToAssets(totalSupply(), Math.Rounding.Floor);
  }

  function maxRedeem(address owner) public view override returns (uint256) {
    DataTypes.ReserveConfigurationMap memory reserveConfiguration = POOL.getConfiguration(asset());

    if (
      !ReserveConfiguration.getActive(reserveConfiguration) ||
      ReserveConfiguration.getPaused(reserveConfiguration)
    ) {
      return 0;
    }

    uint128 virtualUnderlyingBalance = POOL.getVirtualUnderlyingBalance(asset());
    uint256 underlyingTokenBalanceInShares = convertToShares(virtualUnderlyingBalance);
    uint256 cachedUserBalance = balanceOf(owner);
    return
      underlyingTokenBalanceInShares >= cachedUserBalance
        ? cachedUserBalance
        : underlyingTokenBalanceInShares;
  }

  function maxDeposit(address) public view override returns (uint256) {
    DataTypes.ReserveDataLegacy memory reserveData = POOL.getReserveData(asset());

    if (
      !ReserveConfiguration.getActive(reserveData.configuration) ||
      ReserveConfiguration.getPaused(reserveData.configuration) ||
      ReserveConfiguration.getFrozen(reserveData.configuration)
    ) {
      return 0;
    }

    uint256 supplyCap = ReserveConfiguration.getSupplyCap(reserveData.configuration) *
      (10 ** ReserveConfiguration.getDecimals(reserveData.configuration));

    if (supplyCap == 0) return type(uint256).max;

    uint256 currentSupply = (IAToken(reserveData.aTokenAddress).scaledTotalSupply() +
      reserveData.accruedToTreasury).mulDiv(_rate(), RAY, Math.Rounding.Ceil);
    return currentSupply >= supplyCap ? 0 : supplyCap - currentSupply;
  }

  function latestAnswer() external view returns (int256) {
    uint256 aTokenUnderlyingAssetPrice = ICreditifyOracle(POOL_ADDRESSES_PROVIDER.getPriceOracle())
      .getAssetPrice(asset());

    return int256(aTokenUnderlyingAssetPrice.mulDiv(_rate(), RAY, Math.Rounding.Floor));
  }

  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares,
    bool depositToCreditify
  ) internal virtual {
    if (shares == 0) {
      revert StaticATokenInvalidZeroShares();
    }

    if (depositToCreditify) {
      address cachedAsset = asset();
      SafeERC20.safeTransferFrom(IERC20(cachedAsset), caller, address(this), assets);
      POOL.deposit(cachedAsset, assets, address(this), 0);
    } else {
      ERC4626StataTokenStorage storage $ = _getERC4626StataTokenStorage();
      SafeERC20.safeTransferFrom($._aToken, caller, address(this), assets);
    }
    _mint(receiver, shares);

    emit Deposit(caller, receiver, assets, shares);
  }

  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal virtual override {
    _deposit(caller, receiver, assets, shares, true);
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares,
    bool withdrawFromCreditify
  ) internal virtual {
    if (caller != owner) {
      _spendAllowance(owner, caller, shares);
    }

    _burn(owner, shares);
    if (withdrawFromCreditify) {
      POOL.withdraw(asset(), assets, receiver);
    } else {
      ERC4626StataTokenStorage storage $ = _getERC4626StataTokenStorage();
      SafeERC20.safeTransfer($._aToken, receiver, assets);
    }

    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal virtual override {
    _withdraw(caller, receiver, owner, assets, shares, true);
  }

  function _convertToShares(
    uint256 assets,
    Math.Rounding rounding
  ) internal view virtual override returns (uint256) {
    return assets.mulDiv(RAY, _rate(), rounding);
  }

  function _convertToAssets(
    uint256 shares,
    Math.Rounding rounding
  ) internal view virtual override returns (uint256) {
    return shares.mulDiv(_rate(), RAY, rounding);
  }

  function _rate() internal view returns (uint256) {
    return POOL.getReserveNormalizedIncome(asset());
  }
}
