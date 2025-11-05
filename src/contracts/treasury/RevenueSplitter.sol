// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRevenueSplitter} from './IRevenueSplitter.sol';
import {IERC20} from '../dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeERC20} from '../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {PercentageMath} from '../protocol/libraries/math/PercentageMath.sol';
import {ReentrancyGuard} from '../dependencies/openzeppelin/ReentrancyGuard.sol';

contract RevenueSplitter is IRevenueSplitter, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using PercentageMath for uint256;

  address payable public immutable RECIPIENT_A;
  address payable public immutable RECIPIENT_B;
  uint16 public immutable SPLIT_PERCENTAGE_RECIPIENT_A;

  event RevenueSplit(
    address indexed token,
    uint256 totalAmount,
    uint256 amountA,
    uint256 amountB
  );

  constructor(
    address recipientA,
    address recipientB,
    uint16 splitPercentageRecipientA
  ) {
    if (recipientA == address(0) || recipientB == address(0)) {
      revert InvalidPercentSplit();
    }
    if (
      splitPercentageRecipientA == 0 ||
      splitPercentageRecipientA >= PercentageMath.PERCENTAGE_FACTOR
    ) {
      revert InvalidPercentSplit();
    }

    RECIPIENT_A = payable(recipientA);
    RECIPIENT_B = payable(recipientB);
    SPLIT_PERCENTAGE_RECIPIENT_A = splitPercentageRecipientA;
  }

  function splitRevenue(IERC20[] memory tokens) external nonReentrant {
    uint256 tokensLength = tokens.length;
    for (uint256 i; i < tokensLength; ++i) {
      uint256 balance = tokens[i].balanceOf(address(this));

      if (balance == 0) {
        continue;
      }

      uint256 amountA = balance.percentMul(SPLIT_PERCENTAGE_RECIPIENT_A);
      uint256 amountB = balance - amountA;

      tokens[i].safeTransfer(RECIPIENT_A, amountA);
      tokens[i].safeTransfer(RECIPIENT_B, amountB);

      emit RevenueSplit(address(tokens[i]), balance, amountA, amountB);
    }
  }

  function splitNativeRevenue() external nonReentrant {
    uint256 balance = address(this).balance;

    if (balance == 0) {
      return;
    }

    uint256 amountA = balance.percentMul(SPLIT_PERCENTAGE_RECIPIENT_A);
    uint256 amountB = balance - amountA;

    (bool successA, ) = RECIPIENT_A.call{value: amountA}('');
    (bool successB, ) = RECIPIENT_B.call{value: amountB}('');

    emit RevenueSplit(address(0), balance, amountA, amountB);
  }

  receive() external payable {}
}
