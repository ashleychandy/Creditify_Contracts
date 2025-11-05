// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMath} from '../../libraries/math/WadRayMath.sol';

library TokenMath {
  using WadRayMath for uint256;

  function getATokenMintScaledAmount(
    uint256 amount,
    uint256 liquidityIndex
  ) internal pure returns (uint256) {
    return amount.rayDivFloor(liquidityIndex);
  }

  function getATokenBurnScaledAmount(
    uint256 amount,
    uint256 liquidityIndex
  ) internal pure returns (uint256) {
    return amount.rayDivCeil(liquidityIndex);
  }

  function getATokenTransferScaledAmount(
    uint256 amount,
    uint256 liquidityIndex
  ) internal pure returns (uint256) {
    return amount.rayDivCeil(liquidityIndex);
  }

  function getATokenBalance(
    uint256 scaledAmount,
    uint256 liquidityIndex
  ) internal pure returns (uint256) {
    return scaledAmount.rayMulFloor(liquidityIndex);
  }

  function getVTokenMintScaledAmount(
    uint256 amount,
    uint256 variableBorrowIndex
  ) internal pure returns (uint256) {
    return amount.rayDivCeil(variableBorrowIndex);
  }

  function getVTokenBurnScaledAmount(
    uint256 amount,
    uint256 variableBorrowIndex
  ) internal pure returns (uint256) {
    return amount.rayDivFloor(variableBorrowIndex);
  }

  function getVTokenBalance(
    uint256 scaledAmount,
    uint256 variableBorrowIndex
  ) internal pure returns (uint256) {
    return scaledAmount.rayMulCeil(variableBorrowIndex);
  }
}
