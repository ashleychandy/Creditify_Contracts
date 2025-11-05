// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {AggregatorInterface} from '../../dependencies/chainlink/AggregatorInterface.sol';
import {RewardsDataTypes} from '../libraries/RewardsDataTypes.sol';
import {ITransferStrategyBase} from './ITransferStrategyBase.sol';
import {IRewardsController} from './IRewardsController.sol';

interface IEmissionManager {
  
  event EmissionAdminUpdated(
    address indexed reward,
    address indexed oldAdmin,
    address indexed newAdmin
  );

  function configureAssets(RewardsDataTypes.RewardsConfigInput[] memory config) external;

  function setTransferStrategy(address reward, ITransferStrategyBase transferStrategy) external;

  function setRewardOracle(address reward, AggregatorInterface rewardOracle) external;

  function setDistributionEnd(address asset, address reward, uint32 newDistributionEnd) external;

  function setEmissionPerSecond(
    address asset,
    address[] calldata rewards,
    uint88[] calldata newEmissionsPerSecond
  ) external;

  function setClaimer(address user, address claimer) external;

  function setEmissionAdmin(address reward, address admin) external;

  function setRewardsController(address controller) external;

  function getRewardsController() external view returns (IRewardsController);

  function getEmissionAdmin(address reward) external view returns (address);
}
