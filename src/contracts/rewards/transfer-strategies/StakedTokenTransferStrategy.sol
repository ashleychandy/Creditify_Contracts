// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IStakedToken} from '../interfaces/IStakedToken.sol';
import {IStakedTokenTransferStrategy} from '../interfaces/IStakedTokenTransferStrategy.sol';
import {ITransferStrategyBase} from '../interfaces/ITransferStrategyBase.sol';
import {TransferStrategyBase} from './TransferStrategyBase.sol';
import {SafeERC20} from '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';

contract StakedTokenTransferStrategy is TransferStrategyBase, IStakedTokenTransferStrategy {
  using SafeERC20 for IERC20;

  IStakedToken internal immutable STAKE_CONTRACT;
  address internal immutable UNDERLYING_TOKEN;

  constructor(
    address incentivesController,
    address rewardsAdmin,
    IStakedToken stakeToken
  ) TransferStrategyBase(incentivesController, rewardsAdmin) {
    STAKE_CONTRACT = stakeToken;
    UNDERLYING_TOKEN = STAKE_CONTRACT.STAKED_TOKEN();

    IERC20(UNDERLYING_TOKEN).approve(address(STAKE_CONTRACT), 0);
    IERC20(UNDERLYING_TOKEN).approve(address(STAKE_CONTRACT), type(uint256).max);
  }

  function performTransfer(
    address to,
    address reward,
    uint256 amount
  )
    external
    override(TransferStrategyBase, ITransferStrategyBase)
    onlyIncentivesController
    returns (bool)
  {
    require(reward == address(STAKE_CONTRACT), 'REWARD_TOKEN_NOT_STAKE_CONTRACT');

    STAKE_CONTRACT.stake(to, amount);

    return true;
  }

  function renewApproval() external onlyRewardsAdmin {
    IERC20(UNDERLYING_TOKEN).approve(address(STAKE_CONTRACT), 0);
    IERC20(UNDERLYING_TOKEN).approve(address(STAKE_CONTRACT), type(uint256).max);
  }

  function dropApproval() external onlyRewardsAdmin {
    IERC20(UNDERLYING_TOKEN).approve(address(STAKE_CONTRACT), 0);
  }

  function getStakeContract() external view returns (address) {
    return address(STAKE_CONTRACT);
  }

  function getUnderlyingToken() external view returns (address) {
    return UNDERLYING_TOKEN;
  }
}
