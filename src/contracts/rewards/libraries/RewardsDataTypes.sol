// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransferStrategyBase} from '../interfaces/ITransferStrategyBase.sol';
import {AggregatorInterface} from '../../dependencies/chainlink/AggregatorInterface.sol';

library RewardsDataTypes {
  struct RewardsConfigInput {
    uint88 emissionPerSecond;
    uint256 totalSupply;
    uint32 distributionEnd;
    address asset;
    address reward;
    ITransferStrategyBase transferStrategy;
    AggregatorInterface rewardOracle;
  }

  struct UserAssetBalance {
    address asset;
    uint256 userBalance;
    uint256 totalSupply;
  }

  struct UserData {
    
    uint104 index;
    
    uint128 accrued;
  }

  struct RewardData {
    
    uint104 index;
    
    uint88 emissionPerSecond;
    
    uint32 lastUpdateTimestamp;
    
    uint32 distributionEnd;
    
    mapping(address => UserData) usersData;
  }

  struct AssetData {
    
    mapping(address => RewardData) rewards;
    
    mapping(uint128 => address) availableRewards;
    
    uint128 availableRewardsCount;
    
    uint8 decimals;
  }
}
