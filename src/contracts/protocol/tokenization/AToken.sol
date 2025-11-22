// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {IERC20} from "../../dependencies/openzeppelin/contracts/IERC20.sol";
import {SafeERC20} from "../../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {VersionedInitializable} from "../../misc/creditify-upgradeability/VersionedInitializable.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {IAToken} from "../../interfaces/IAToken.sol";
import {ICreditifyIncentivesController} from "../../interfaces/ICreditifyIncentivesController.sol";
import {IInitializableAToken} from "../../interfaces/IInitializableAToken.sol";
import {ScaledBalanceTokenBase} from "./base/ScaledBalanceTokenBase.sol";
import {IncentivizedERC20} from "./base/IncentivizedERC20.sol";
import {EIP712Base} from "./base/EIP712Base.sol";
import {TokenMath} from "../libraries/helpers/TokenMath.sol";

abstract contract AToken is VersionedInitializable, ScaledBalanceTokenBase, EIP712Base, IAToken {
    using TokenMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    address public immutable TREASURY;

    address internal _deprecated_treasury;
    address internal _underlyingAsset;

    constructor(IPool pool, address rewardsController, address treasury)
        ScaledBalanceTokenBase(pool, "ATOKEN_IMPL", "ATOKEN_IMPL", 0, rewardsController)
        EIP712Base()
    {
        require(treasury != address(0), Errors.ZeroAddressNotValid());
        TREASURY = treasury;
    }

    function initialize(
        IPool initializingPool,
        address underlyingAsset,
        uint8 aTokenDecimals,
        string calldata aTokenName,
        string calldata aTokenSymbol,
        bytes calldata params
    ) public virtual;

    function mint(address caller, address onBehalfOf, uint256 scaledAmount, uint256 index)
        external
        virtual
        override
        onlyPool
        returns (bool)
    {
        return _mintScaled({
            caller: caller,
            onBehalfOf: onBehalfOf,
            amountScaled: scaledAmount,
            index: index,
            getTokenBalance: TokenMath.getATokenBalance
        });
    }

    function burn(address from, address receiverOfUnderlying, uint256 amount, uint256 scaledAmount, uint256 index)
        external
        virtual
        override
        onlyPool
        returns (bool)
    {
        bool zeroBalanceAfterBurn = _burnScaled({
            user: from,
            target: receiverOfUnderlying,
            amountScaled: scaledAmount,
            index: index,
            getTokenBalance: TokenMath.getATokenBalance
        });

        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
        return zeroBalanceAfterBurn;
    }

    function mintToTreasury(uint256 scaledAmount, uint256 index) external virtual override onlyPool {
        if (scaledAmount == 0) {
            return;
        }
        _mintScaled({
            caller: address(POOL),
            onBehalfOf: TREASURY,
            amountScaled: scaledAmount,
            index: index,
            getTokenBalance: TokenMath.getATokenBalance
        });
    }

    function transferOnLiquidation(address from, address to, uint256 amount, uint256 scaledAmount, uint256 index)
        external
        virtual
        override
        onlyPool
    {
        _transfer({sender: from, recipient: to, amount: amount, scaledAmount: scaledAmount.toUint120(), index: index});
    }

    function balanceOf(address user) public view virtual override(IncentivizedERC20, IERC20) returns (uint256) {
        return super.balanceOf(user).getATokenBalance(POOL.getReserveNormalizedIncome(_underlyingAsset));
    }

    function totalSupply() public view virtual override(IncentivizedERC20, IERC20) returns (uint256) {
        return super.totalSupply().getATokenBalance(POOL.getReserveNormalizedIncome(_underlyingAsset));
    }

    function RESERVE_TREASURY_ADDRESS() external view override returns (address) {
        return TREASURY;
    }

    function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
        return _underlyingAsset;
    }

    function transferUnderlyingTo(address target, uint256 amount) external virtual override onlyPool {
        IERC20(_underlyingAsset).safeTransfer(target, amount);
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {
        require(owner != address(0), Errors.ZeroAddressNotValid());

        require(block.timestamp <= deadline, Errors.InvalidExpiration());
        uint256 currentValidNonce = _nonces[owner];
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
            )
        );
        require(owner == ECDSA.recover(digest, v, r, s), Errors.InvalidSignature());
        _nonces[owner] = currentValidNonce + 1;
        _approve(owner, spender, value);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        external
        virtual
        override(IERC20, IncentivizedERC20)
        returns (bool)
    {
        uint256 index = POOL.getReserveNormalizedIncome(_underlyingAsset);
        uint256 scaledBalanceOfSender = super.balanceOf(sender);
        _spendAllowance(
            sender,
            _msgSender(),
            amount,
            scaledBalanceOfSender.getATokenBalance(index)
                - (scaledBalanceOfSender - amount.getATokenTransferScaledAmount(index)).getATokenBalance(index)
        );
        _transfer(sender, recipient, amount.toUint120());
        return true;
    }

    function _transfer(address from, address to, uint120 amount) internal virtual override {
        address underlyingAsset = _underlyingAsset;

        uint256 index = POOL.getReserveNormalizedIncome(underlyingAsset);

        uint256 scaledBalanceFromBefore = super.balanceOf(from);
        uint256 scaledBalanceToBefore = super.balanceOf(to);
        uint256 scaledAmount = uint256(amount).getATokenTransferScaledAmount(index);

        _transfer({sender: from, recipient: to, amount: amount, scaledAmount: scaledAmount.toUint120(), index: index});

        POOL.finalizeTransfer({
            asset: underlyingAsset,
            from: from,
            to: to,
            scaledAmount: scaledAmount,
            scaledBalanceFromBefore: scaledBalanceFromBefore,
            scaledBalanceToBefore: scaledBalanceToBefore
        });
    }

    function _transfer(address sender, address recipient, uint256 amount, uint120 scaledAmount, uint256 index)
        internal
        virtual
    {
        uint256 senderScaledBalance = super.balanceOf(sender);
        uint256 senderBalanceIncrease = senderScaledBalance.getATokenBalance(index)
            - senderScaledBalance.getATokenBalance(_userState[sender].additionalData);

        uint256 recipientScaledBalance = super.balanceOf(recipient);
        uint256 recipientBalanceIncrease = recipientScaledBalance.getATokenBalance(index)
            - recipientScaledBalance.getATokenBalance(_userState[recipient].additionalData);

        _userState[sender].additionalData = index.toUint128();
        _userState[recipient].additionalData = index.toUint128();

        super._transfer(sender, recipient, scaledAmount);

        if (senderBalanceIncrease > 0) {
            emit Transfer(address(0), sender, senderBalanceIncrease);
            emit Mint(_msgSender(), sender, senderBalanceIncrease, senderBalanceIncrease, index);
        }

        if (sender != recipient && recipientBalanceIncrease > 0) {
            emit Transfer(address(0), recipient, recipientBalanceIncrease);
            emit Mint(_msgSender(), recipient, recipientBalanceIncrease, recipientBalanceIncrease, index);
        }

        emit Transfer(sender, recipient, amount);
        emit BalanceTransfer(sender, recipient, scaledAmount, index);
    }

    function DOMAIN_SEPARATOR() public view override(IAToken, EIP712Base) returns (bytes32) {
        return super.DOMAIN_SEPARATOR();
    }

    function nonces(address owner) public view override(IAToken, EIP712Base) returns (uint256) {
        return super.nonces(owner);
    }

    function _EIP712BaseId() internal view override returns (string memory) {
        return name();
    }

    function rescueTokens(address token, address to, uint256 amount) external override onlyPoolAdmin {
        require(token != _underlyingAsset, Errors.UnderlyingCannotBeRescued());
        IERC20(token).safeTransfer(to, amount);
    }
}
