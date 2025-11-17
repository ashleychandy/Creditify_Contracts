// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PercentageMath {
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    assembly {
      if iszero(
        or(
          iszero(percentage),
          iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
        )
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
    }
  }

  function percentMulCeil(
    uint256 value,
    uint256 percentage
  ) internal pure returns (uint256 result) {
    assembly {
      if iszero(or(iszero(percentage), iszero(gt(value, div(not(0), percentage))))) {
        revert(0, 0)
      }

      let product := mul(value, percentage)
      result := add(
        div(product, PERCENTAGE_FACTOR),
        iszero(iszero(mod(product, PERCENTAGE_FACTOR)))
      )
    }
  }

  function percentMulFloor(
    uint256 value,
    uint256 percentage
  ) internal pure returns (uint256 result) {
    assembly {
      if iszero(or(iszero(percentage), iszero(gt(value, div(not(0), percentage))))) {
        revert(0, 0)
      }

      result := div(mul(value, percentage), PERCENTAGE_FACTOR)
    }
  }

  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    assembly {
      if or(
        iszero(percentage),
        iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
    }
  }

  function percentDivCeil(
    uint256 value,
    uint256 percentage
  ) internal pure returns (uint256 result) {
    assembly {
      if or(iszero(percentage), iszero(iszero(gt(value, div(not(0), PERCENTAGE_FACTOR))))) {
        revert(0, 0)
      }
      let val := mul(value, PERCENTAGE_FACTOR)
      result := add(div(val, percentage), iszero(iszero(mod(val, percentage))))
    }
  }
}
