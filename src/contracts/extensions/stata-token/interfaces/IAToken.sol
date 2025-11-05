// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IAToken {
  function POOL() external view returns (address);

  function getIncentivesController() external view returns (address);

  function UNDERLYING_ASSET_ADDRESS() external view returns (address);

  function RESERVE_TREASURY_ADDRESS() external view returns (address);

  function scaledTotalSupply() external view returns (uint256);
}
