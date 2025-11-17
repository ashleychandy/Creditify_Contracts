// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMath} from './WadRayMath.sol';

library MathUtils {
  using WadRayMath for uint256;

  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  function calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    uint256 result = rate * (block.timestamp - uint256(lastUpdateTimestamp));
    unchecked {
      result = result / SECONDS_PER_YEAR;
    }

    return WadRayMath.RAY + result;
  }

  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    uint256 exp = currentTimestamp - uint256(lastUpdateTimestamp);

    if (exp == 0) {
      return WadRayMath.RAY;
    }

    unchecked {
      uint256 x = (rate * exp) / SECONDS_PER_YEAR;

      return WadRayMath.RAY + x + x.rayMul(x / 2 + x.rayMul(x / 6));
    }
  }

  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
  }

  function mulDivCeil(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 d) {
    assembly {
      if iszero(c) {
        revert(0, 0)
      }

      if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
        revert(0, 0)
      }

      let product := mul(a, b)
      d := add(div(product, c), iszero(iszero(mod(product, c))))
    }
  }
}
