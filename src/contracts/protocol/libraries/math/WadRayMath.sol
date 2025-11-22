// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WadRayMath {
    enum Rounding {
        Floor,
        Ceil
    }

    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_WAD), WAD)
        }
    }

    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) { revert(0, 0) }

            c := div(add(mul(a, WAD), div(b, 2)), b)
        }
    }

    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) { revert(0, 0) }
            c := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    function rayMulFloor(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) { revert(0, 0) }

            c := div(mul(a, b), RAY)
        }
    }

    function rayMulCeil(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) { revert(0, 0) }

            let product := mul(a, b)
            c := add(div(product, RAY), iszero(iszero(mod(product, RAY))))
        }
    }

    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) { revert(0, 0) }
            c := div(add(mul(a, RAY), div(b, 2)), b)
        }
    }

    function rayDivCeil(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(not(0), RAY))))) { revert(0, 0) }
            let scaled := mul(a, RAY)
            c := add(div(scaled, b), iszero(iszero(mod(scaled, b))))
        }
    }

    function rayDivFloor(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(not(0), RAY))))) { revert(0, 0) }
            c := div(mul(a, RAY), b)
        }
    }

    function rayToWad(uint256 a) internal pure returns (uint256 b) {
        assembly {
            b := div(a, WAD_RAY_RATIO)
            let remainder := mod(a, WAD_RAY_RATIO)
            if iszero(lt(remainder, div(WAD_RAY_RATIO, 2))) { b := add(b, 1) }
        }
    }

    function wadToRay(uint256 a) internal pure returns (uint256 b) {
        assembly {
            b := mul(a, WAD_RAY_RATIO)

            if iszero(eq(div(b, WAD_RAY_RATIO), a)) { revert(0, 0) }
        }
    }
}
