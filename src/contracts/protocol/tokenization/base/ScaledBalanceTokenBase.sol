// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {WadRayMath} from '../../libraries/math/WadRayMath.sol';
import {IPool} from '../../../interfaces/IPool.sol';
import {IScaledBalanceToken} from '../../../interfaces/IScaledBalanceToken.sol';
import {MintableIncentivizedERC20} from './MintableIncentivizedERC20.sol';

abstract contract ScaledBalanceTokenBase is MintableIncentivizedERC20, IScaledBalanceToken {
  using WadRayMath for uint256;
  using SafeCast for uint256;

  constructor(
    IPool pool,
    string memory name,
    string memory symbol,
    uint8 decimals,
    address rewardsController
  ) MintableIncentivizedERC20(pool, name, symbol, decimals, rewardsController) {}

  function scaledBalanceOf(address user) external view override returns (uint256) {
    return super.balanceOf(user);
  }

  function getScaledUserBalanceAndSupply(
    address user
  ) external view override returns (uint256, uint256) {
    return (super.balanceOf(user), super.totalSupply());
  }

  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  function getPreviousIndex(address user) external view virtual override returns (uint256) {
    return _userState[user].additionalData;
  }

  function _mintScaled(
    address caller,
    address onBehalfOf,
    uint256 amountScaled,
    uint256 index,
    function(uint256, uint256) internal pure returns (uint256) getTokenBalance
  ) internal returns (bool) {
    require(amountScaled != 0, Errors.InvalidMintAmount());

    uint256 scaledBalance = super.balanceOf(onBehalfOf);
    uint256 nextBalance = getTokenBalance(amountScaled + scaledBalance, index);
    uint256 previousBalance = getTokenBalance(scaledBalance, _userState[onBehalfOf].additionalData);
    uint256 balanceIncrease = getTokenBalance(scaledBalance, index) - previousBalance;

    _userState[onBehalfOf].additionalData = index.toUint128();

    _mint(onBehalfOf, amountScaled.toUint120());

    uint256 amountToMint = nextBalance - previousBalance;
    emit Transfer(address(0), onBehalfOf, amountToMint);
    emit Mint(caller, onBehalfOf, amountToMint, balanceIncrease, index);

    return (scaledBalance == 0);
  }

  function _burnScaled(
    address user,
    address target,
    uint256 amountScaled,
    uint256 index,
    function(uint256, uint256) internal pure returns (uint256) getTokenBalance
  ) internal returns (bool) {
    require(amountScaled != 0, Errors.InvalidBurnAmount());

    uint256 scaledBalance = super.balanceOf(user);
    uint256 nextBalance = getTokenBalance(scaledBalance - amountScaled, index);
    uint256 previousBalance = getTokenBalance(scaledBalance, _userState[user].additionalData);
    uint256 balanceIncrease = getTokenBalance(scaledBalance, index) - previousBalance;

    _userState[user].additionalData = index.toUint128();

    _burn(user, amountScaled.toUint120());

    if (nextBalance > previousBalance) {
      uint256 amountToMint = nextBalance - previousBalance;
      emit Transfer(address(0), user, amountToMint);
      emit Mint(user, user, amountToMint, balanceIncrease, index);
    } else {
      uint256 amountToBurn = previousBalance - nextBalance;
      emit Transfer(user, address(0), amountToBurn);
      emit Burn(user, target, amountToBurn, balanceIncrease, index);
    }

    return scaledBalance - amountScaled == 0;
  }
}
