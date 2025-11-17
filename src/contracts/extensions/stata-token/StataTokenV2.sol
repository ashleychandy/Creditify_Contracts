// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Upgradeable, ERC20PermitUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import {PausableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol';
import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IRescuable, Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {IRescuableBase, RescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';

import {IACLManager} from '../../../contracts/interfaces/IACLManager.sol';
import {ERC4626Upgradeable, ERC4626StataTokenUpgradeable, IPool, Math, IERC20} from './ERC4626StataTokenUpgradeable.sol';
import {ERC20CreditifyLMUpgradeable, IRewardsController} from './ERC20CreditifyLMUpgradeable.sol';
import {IStataTokenV2} from './interfaces/IStataTokenV2.sol';
import {IAToken} from './interfaces/IAToken.sol';

contract StataTokenV2 is
  ERC20PermitUpgradeable,
  ERC20CreditifyLMUpgradeable,
  ERC4626StataTokenUpgradeable,
  PausableUpgradeable,
  Rescuable,
  IStataTokenV2
{
  using Math for uint256;

  constructor(
    IPool pool,
    IRewardsController rewardsController
  ) ERC20CreditifyLMUpgradeable(rewardsController) ERC4626StataTokenUpgradeable(pool) {
    _disableInitializers();
  }

  modifier onlyPauseGuardian() {
    if (!canPause(_msgSender())) revert OnlyPauseGuardian(_msgSender());
    _;
  }

  function initialize(
    address aToken,
    string calldata staticATokenName,
    string calldata staticATokenSymbol
  ) external initializer {
    __ERC20_init(staticATokenName, staticATokenSymbol);
    __ERC20Permit_init(staticATokenName);
    __ERC20CreditifyLM_init(aToken);
    __ERC4626StataToken_init(aToken);
    __Pausable_init();
  }

  function setPaused(bool paused) external onlyPauseGuardian {
    if (paused) _pause();
    else _unpause();
  }

  function whoCanRescue() public view override returns (address) {
    return POOL_ADDRESSES_PROVIDER.getACLAdmin();
  }

  function maxRescue(
    address asset
  ) public view override(IRescuableBase, RescuableBase) returns (uint256) {
    address cachedAToken = aToken();
    if (asset == cachedAToken) {
      uint256 requiredBacking = _convertToAssets(totalSupply(), Math.Rounding.Ceil);
      uint256 balance = IERC20(cachedAToken).balanceOf(address(this));
      return balance > requiredBacking ? balance - requiredBacking : 0;
    }
    return type(uint256).max;
  }

  function canPause(address actor) public view returns (bool) {
    return IACLManager(POOL_ADDRESSES_PROVIDER.getACLManager()).isEmergencyAdmin(actor);
  }

  function nonces(
    address owner
  ) public view virtual override(ERC20PermitUpgradeable, IERC20Permit) returns (uint256) {
    return super.nonces(owner);
  }

  function decimals()
    public
    view
    override(IERC20Metadata, ERC20Upgradeable, ERC4626Upgradeable)
    returns (uint8)
  {
    return ERC4626Upgradeable.decimals();
  }

  function _claimRewardsOnBehalf(
    address onBehalfOf,
    address receiver,
    address[] memory rewards
  ) internal virtual override whenNotPaused {
    super._claimRewardsOnBehalf(onBehalfOf, receiver, rewards);
  }

  function _update(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20CreditifyLMUpgradeable, ERC20Upgradeable) whenNotPaused {
    ERC20CreditifyLMUpgradeable._update(from, to, amount);
  }
}
