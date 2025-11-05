// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IRewardsDistributor} from './IRewardsDistributor.sol';
import {ITransferStrategyBase} from './ITransferStrategyBase.sol';
import {AggregatorInterface} from '../../dependencies/chainlink/AggregatorInterface.sol';
import {RewardsDataTypes} from '../libraries/RewardsDataTypes.sol';

interface IRewardsController is IRewardsDistributor {
  
  event ClaimerSet(address indexed user, address indexed claimer);

  event RewardsClaimed(
    address indexed user,
    address indexed reward,
    address indexed to,
    address claimer,
    uint256 amount
  );

  event TransferStrategyInstalled(address indexed reward, address indexed transferStrategy);

  event RewardOracleUpdated(address indexed reward, address indexed rewardOracle);

  function setClaimer(address user, address claimer) external;

  function setTransferStrategy(address reward, ITransferStrategyBase transferStrategy) external;

  function setRewardOracle(address reward, AggregatorInterface rewardOracle) external;

  function getRewardOracle(address reward) external view returns (address);

  function getClaimer(address user) external view returns (address);

  function getTransferStrategy(address reward) external view returns (address);

  function configureAssets(RewardsDataTypes.RewardsConfigInput[] memory config) external;

  function handleAction(address user, uint256 totalSupply, uint256 userBalance) external;

  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to,
    address reward
  ) external returns (uint256);

  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to,
    address reward
  ) external returns (uint256);

  function claimRewardsToSelf(
    address[] calldata assets,
    uint256 amount,
    address reward
  ) external returns (uint256);

  function claimAllRewards(
    address[] calldata assets,
    address to
  ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

  function claimAllRewardsOnBehalf(
    address[] calldata assets,
    address user,
    address to
  ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

  function claimAllRewardsToSelf(
    address[] calldata assets
  ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}
