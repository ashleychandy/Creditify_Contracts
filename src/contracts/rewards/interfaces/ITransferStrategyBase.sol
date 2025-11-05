// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITransferStrategyBase {
  error CallerNotIncentivesController();
  error OnlyRewardsAdmin();

  event EmergencyWithdrawal(
    address indexed caller,
    address indexed token,
    address indexed to,
    uint256 amount
  );

  function performTransfer(address to, address reward, uint256 amount) external returns (bool);

  function getIncentivesController() external view returns (address);

  function getRewardsAdmin() external view returns (address);

  function emergencyWithdrawal(address token, address to, uint256 amount) external;
}
