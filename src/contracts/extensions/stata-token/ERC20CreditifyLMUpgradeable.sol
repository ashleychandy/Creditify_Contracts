// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/interfaces/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

import {IRewardsController} from '../../rewards/interfaces/IRewardsController.sol';
import {IERC20CreditifyLM} from './interfaces/IERC20CreditifyLM.sol';

abstract contract ERC20CreditifyLMUpgradeable is ERC20Upgradeable, IERC20CreditifyLM {
  using SafeCast for uint256;

  struct ERC20CreditifyLMStorage {
    address _referenceAsset; 
    address[] _rewardTokens;
    mapping(address reward => RewardIndexCache cache) _startIndex;
    mapping(address user => mapping(address reward => UserRewardsData cache)) _userRewardsData;
  }

  bytes32 private constant ERC20CreditifyLMStorageLocation =
    0xbd1b5b2ceb5baf0e32281101f0f4a10cc90fcac9dd798d66baf9cd54c1c00e00;

  function _getERC20CreditifyLMStorage() private pure returns (ERC20CreditifyLMStorage storage $) {
    assembly {
      $.slot := ERC20CreditifyLMStorageLocation
    }
  }

  IRewardsController public immutable INCENTIVES_CONTROLLER;

  constructor(IRewardsController rewardsController) {
    if (address(rewardsController) == address(0)) {
      revert ZeroIncentivesControllerIsForbidden();
    }
    INCENTIVES_CONTROLLER = rewardsController;
  }

  function __ERC20CreditifyLM_init(address referenceAsset_) internal onlyInitializing {
    __ERC20CreditifyLM_init_unchained(referenceAsset_);
  }

  function __ERC20CreditifyLM_init_unchained(address referenceAsset_) internal onlyInitializing {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    $._referenceAsset = referenceAsset_;

    if (INCENTIVES_CONTROLLER != IRewardsController(address(0))) {
      refreshRewardTokens();
    }
  }

  function claimRewardsOnBehalf(
    address onBehalfOf,
    address receiver,
    address[] memory rewards
  ) external {
    address msgSender = _msgSender();
    if (msgSender != onBehalfOf && msgSender != INCENTIVES_CONTROLLER.getClaimer(onBehalfOf)) {
      revert InvalidClaimer(msgSender);
    }

    _claimRewardsOnBehalf(onBehalfOf, receiver, rewards);
  }

  function claimRewards(address receiver, address[] memory rewards) external {
    _claimRewardsOnBehalf(_msgSender(), receiver, rewards);
  }

  function claimRewardsToSelf(address[] memory rewards) external {
    _claimRewardsOnBehalf(_msgSender(), _msgSender(), rewards);
  }

  function refreshRewardTokens() public override {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    address[] memory rewards = INCENTIVES_CONTROLLER.getRewardsByAsset($._referenceAsset);
    for (uint256 i = 0; i < rewards.length; i++) {
      _registerRewardToken(rewards[i]);
    }
  }

  function collectAndUpdateRewards(address reward) public returns (uint256) {
    if (reward == address(0)) {
      return 0;
    }

    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    address[] memory assets = new address[](1);
    assets[0] = address($._referenceAsset);

    return INCENTIVES_CONTROLLER.claimRewards(assets, type(uint256).max, address(this), reward);
  }

  function isRegisteredRewardToken(address reward) public view override returns (bool) {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    return $._startIndex[reward].isRegistered;
  }

  function getCurrentRewardsIndex(address reward) public view returns (uint256) {
    if (address(reward) == address(0)) {
      return 0;
    }
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    (, uint256 nextIndex) = INCENTIVES_CONTROLLER.getAssetIndex($._referenceAsset, reward);
    return nextIndex;
  }

  function getTotalClaimableRewards(address reward) external view returns (uint256) {
    if (reward == address(0)) {
      return 0;
    }

    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    address[] memory assets = new address[](1);
    assets[0] = $._referenceAsset;
    uint256 freshRewards = INCENTIVES_CONTROLLER.getUserRewards(assets, address(this), reward);
    return IERC20(reward).balanceOf(address(this)) + freshRewards;
  }

  function getClaimableRewards(address user, address reward) external view returns (uint256) {
    return _getClaimableRewards(user, reward, balanceOf(user), getCurrentRewardsIndex(reward));
  }

  function getUnclaimedRewards(address user, address reward) external view returns (uint256) {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    return $._userRewardsData[user][reward].unclaimedRewards;
  }

  function getReferenceAsset() external view returns (address) {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    return $._referenceAsset;
  }

  function rewardTokens() external view returns (address[] memory) {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    return $._rewardTokens;
  }

  function _update(address from, address to, uint256 amount) internal virtual override {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    for (uint256 i = 0; i < $._rewardTokens.length; i++) {
      address rewardToken = address($._rewardTokens[i]);
      uint256 rewardsIndex = getCurrentRewardsIndex(rewardToken);
      if (from != address(0)) {
        _updateUser(from, rewardsIndex, rewardToken);
      }
      if (to != address(0) && from != to) {
        _updateUser(to, rewardsIndex, rewardToken);
      }
    }
    super._update(from, to, amount);
  }

  function _updateUser(address user, uint256 currentRewardsIndex, address rewardToken) internal {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    uint256 balance = balanceOf(user);
    if (balance > 0) {
      $._userRewardsData[user][rewardToken].unclaimedRewards = _getClaimableRewards(
        user,
        rewardToken,
        balance,
        currentRewardsIndex
      ).toUint128();
    }
    $._userRewardsData[user][rewardToken].rewardsIndexOnLastInteraction = currentRewardsIndex
      .toUint128();
  }

  function _getPendingRewards(
    uint256 balance,
    uint256 rewardsIndexOnLastInteraction,
    uint256 currentRewardsIndex
  ) internal view returns (uint256) {
    if (balance == 0) {
      return 0;
    }
    return (balance * (currentRewardsIndex - rewardsIndexOnLastInteraction)) / 10 ** decimals();
  }

  function _getClaimableRewards(
    address user,
    address reward,
    uint256 balance,
    uint256 currentRewardsIndex
  ) internal view returns (uint256) {
    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    RewardIndexCache memory rewardsIndexCache = $._startIndex[reward];
    if (!rewardsIndexCache.isRegistered) {
      revert RewardNotInitialized(reward);
    }

    UserRewardsData memory currentUserRewardsData = $._userRewardsData[user][reward];
    return
      currentUserRewardsData.unclaimedRewards +
      _getPendingRewards(
        balance,
        currentUserRewardsData.rewardsIndexOnLastInteraction == 0
          ? rewardsIndexCache.lastUpdatedIndex
          : currentUserRewardsData.rewardsIndexOnLastInteraction,
        currentRewardsIndex
      );
  }

  function _claimRewardsOnBehalf(
    address onBehalfOf,
    address receiver,
    address[] memory rewards
  ) internal virtual {
    for (uint256 i = 0; i < rewards.length; i++) {
      if (address(rewards[i]) == address(0)) {
        continue;
      }
      uint256 currentRewardsIndex = getCurrentRewardsIndex(rewards[i]);
      uint256 balance = balanceOf(onBehalfOf);
      uint256 userReward = _getClaimableRewards(
        onBehalfOf,
        rewards[i],
        balance,
        currentRewardsIndex
      );
      uint256 totalRewardTokenBalance = IERC20(rewards[i]).balanceOf(address(this));
      uint256 unclaimedReward = 0;

      if (userReward > totalRewardTokenBalance) {
        totalRewardTokenBalance += collectAndUpdateRewards(address(rewards[i]));
      }

      if (userReward > totalRewardTokenBalance) {
        unclaimedReward = userReward - totalRewardTokenBalance;
        userReward = totalRewardTokenBalance;
      }
      if (userReward > 0) {
        ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
        $._userRewardsData[onBehalfOf][rewards[i]].unclaimedRewards = unclaimedReward.toUint128();
        $
        ._userRewardsData[onBehalfOf][rewards[i]]
          .rewardsIndexOnLastInteraction = currentRewardsIndex.toUint128();
        SafeERC20.safeTransfer(IERC20(rewards[i]), receiver, userReward);
      }
    }
  }

  function _registerRewardToken(address reward) internal {
    if (isRegisteredRewardToken(reward)) return;
    uint256 startIndex = getCurrentRewardsIndex(reward);

    ERC20CreditifyLMStorage storage $ = _getERC20CreditifyLMStorage();
    $._rewardTokens.push(reward);
    $._startIndex[reward] = RewardIndexCache(true, startIndex.toUint248());

    emit RewardTokenRegistered(reward, startIndex);
  }
}
