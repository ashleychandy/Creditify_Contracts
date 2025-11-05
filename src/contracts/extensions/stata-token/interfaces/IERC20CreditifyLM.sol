// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20CreditifyLM {
  struct UserRewardsData {
    uint128 rewardsIndexOnLastInteraction;
    uint128 unclaimedRewards;
  }

  struct RewardIndexCache {
    bool isRegistered;
    uint248 lastUpdatedIndex;
  }

  error ZeroIncentivesControllerIsForbidden();
  error InvalidClaimer(address claimer);
  error RewardNotInitialized(address reward);

  event RewardTokenRegistered(address indexed reward, uint256 startIndex);

  function collectAndUpdateRewards(address reward) external returns (uint256);

  function claimRewardsOnBehalf(
    address onBehalfOf,
    address receiver,
    address[] memory rewards
  ) external;

  function claimRewards(address receiver, address[] memory rewards) external;

  function claimRewardsToSelf(address[] memory rewards) external;

  function getTotalClaimableRewards(address reward) external view returns (uint256);

  function getClaimableRewards(address user, address reward) external view returns (uint256);

  function getUnclaimedRewards(address user, address reward) external view returns (uint256);

  function getCurrentRewardsIndex(address reward) external view returns (uint256);

  function getReferenceAsset() external view returns (address);

  function rewardTokens() external view returns (address[] memory);

  function refreshRewardTokens() external;

  function isRegisteredRewardToken(address reward) external view returns (bool);
}
