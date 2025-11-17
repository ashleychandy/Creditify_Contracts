// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import {AggregatorInterface} from '../dependencies/chainlink/AggregatorInterface.sol';
import {IEmissionManager} from './interfaces/IEmissionManager.sol';
import {ITransferStrategyBase} from './interfaces/ITransferStrategyBase.sol';
import {IRewardsController} from './interfaces/IRewardsController.sol';
import {RewardsDataTypes} from './libraries/RewardsDataTypes.sol';

contract EmissionManager is Ownable, IEmissionManager {
  mapping(address => address) internal _emissionAdmins;

  IRewardsController internal _rewardsController;

  modifier onlyEmissionAdmin(address reward) {
    require(msg.sender == _emissionAdmins[reward], 'ONLY_EMISSION_ADMIN');
    _;
  }

  constructor(address owner) {
    transferOwnership(owner);
  }

  function configureAssets(RewardsDataTypes.RewardsConfigInput[] memory config) external override {
    for (uint256 i = 0; i < config.length; i++) {
      require(_emissionAdmins[config[i].reward] == msg.sender, 'ONLY_EMISSION_ADMIN');
    }
    _rewardsController.configureAssets(config);
  }

  function setTransferStrategy(
    address reward,
    ITransferStrategyBase transferStrategy
  ) external override onlyEmissionAdmin(reward) {
    _rewardsController.setTransferStrategy(reward, transferStrategy);
  }

  function setRewardOracle(
    address reward,
    AggregatorInterface rewardOracle
  ) external override onlyEmissionAdmin(reward) {
    _rewardsController.setRewardOracle(reward, rewardOracle);
  }

  function setDistributionEnd(
    address asset,
    address reward,
    uint32 newDistributionEnd
  ) external override onlyEmissionAdmin(reward) {
    _rewardsController.setDistributionEnd(asset, reward, newDistributionEnd);
  }

  function setEmissionPerSecond(
    address asset,
    address[] calldata rewards,
    uint88[] calldata newEmissionsPerSecond
  ) external override {
    for (uint256 i = 0; i < rewards.length; i++) {
      require(_emissionAdmins[rewards[i]] == msg.sender, 'ONLY_EMISSION_ADMIN');
    }
    _rewardsController.setEmissionPerSecond(asset, rewards, newEmissionsPerSecond);
  }

  function setClaimer(address user, address claimer) external override onlyOwner {
    _rewardsController.setClaimer(user, claimer);
  }

  function setEmissionAdmin(address reward, address admin) external override onlyOwner {
    address oldAdmin = _emissionAdmins[reward];
    _emissionAdmins[reward] = admin;
    emit EmissionAdminUpdated(reward, oldAdmin, admin);
  }

  function setRewardsController(address controller) external override onlyOwner {
    _rewardsController = IRewardsController(controller);
  }

  function getRewardsController() external view override returns (IRewardsController) {
    return _rewardsController;
  }

  function getEmissionAdmin(address reward) external view override returns (address) {
    return _emissionAdmins[reward];
  }
}
