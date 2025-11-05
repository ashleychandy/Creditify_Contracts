// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '../dependencies/openzeppelin/contracts/IERC20.sol';

interface IRevenueSplitterErrors {
  error InvalidPercentSplit();
}

interface IRevenueSplitter is IRevenueSplitterErrors {

  function splitRevenue(IERC20[] memory tokens) external;

  function splitNativeRevenue() external;

  function RECIPIENT_A() external view returns (address payable);

  function RECIPIENT_B() external view returns (address payable);

  function SPLIT_PERCENTAGE_RECIPIENT_A() external view returns (uint16);
}
