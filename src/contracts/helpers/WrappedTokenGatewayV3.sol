// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from "../dependencies/openzeppelin/contracts/Ownable.sol";
import {IERC20} from "../dependencies/openzeppelin/contracts/IERC20.sol";
import {SafeERC20} from "../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {IWXDC} from "./interfaces/IWXDC.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {ReserveConfiguration} from "../protocol/libraries/configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../protocol/libraries/configuration/UserConfiguration.sol";
import {DataTypes} from "../protocol/libraries/types/DataTypes.sol";
import {IWrappedTokenGatewayV3} from "./interfaces/IWrappedTokenGatewayV3.sol";

contract WrappedTokenGatewayV3 is IWrappedTokenGatewayV3, Ownable {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using SafeERC20 for IERC20;

    IWXDC public immutable WXDC;
    IPool public immutable POOL;

    constructor(address wxdc, address owner, IPool pool) {
        WXDC = IWXDC(wxdc);
        POOL = pool;
        transferOwnership(owner);
        IWXDC(wxdc).approve(address(pool), type(uint256).max);
    }

    function depositXDC(address, address onBehalfOf, uint16 referralCode) external payable override {
        WXDC.deposit{value: msg.value}();
        POOL.deposit(address(WXDC), msg.value, onBehalfOf, referralCode);
    }

    function withdrawXDC(address, uint256 amount, address to) external override {
        IAToken aWXDC = IAToken(POOL.getReserveAToken(address(WXDC)));
        uint256 userBalance = aWXDC.balanceOf(msg.sender);
        uint256 amountToWithdraw = amount;

        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        aWXDC.transferFrom(msg.sender, address(this), amountToWithdraw);
        POOL.withdraw(address(WXDC), amountToWithdraw, address(this));
        WXDC.withdraw(amountToWithdraw);
        _safeTransferXDC(to, amountToWithdraw);
    }

    function repayXDC(address, uint256 amount, address onBehalfOf) external payable override {
        uint256 paybackAmount = IERC20(POOL.getReserveVariableDebtToken(address(WXDC))).balanceOf(onBehalfOf);

        if (amount < paybackAmount) {
            paybackAmount = amount;
        }
        require(msg.value >= paybackAmount, "msg.value is less than repayment amount");
        WXDC.deposit{value: paybackAmount}();
        POOL.repay(address(WXDC), paybackAmount, uint256(DataTypes.InterestRateMode.VARIABLE), onBehalfOf);

        if (msg.value > paybackAmount) _safeTransferXDC(msg.sender, msg.value - paybackAmount);
    }

    function borrowXDC(address, uint256 amount, uint16 referralCode) external override {
        POOL.borrow(address(WXDC), amount, uint256(DataTypes.InterestRateMode.VARIABLE), referralCode, msg.sender);
        WXDC.withdraw(amount);
        _safeTransferXDC(msg.sender, amount);
    }

    function withdrawXDCWithPermit(
        address,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {
        IAToken aWXDC = IAToken(POOL.getReserveAToken(address(WXDC)));
        uint256 userBalance = aWXDC.balanceOf(msg.sender);
        uint256 amountToWithdraw = amount;

        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }

        try aWXDC.permit(msg.sender, address(this), amount, deadline, permitV, permitR, permitS) {} catch {}
        aWXDC.transferFrom(msg.sender, address(this), amountToWithdraw);
        POOL.withdraw(address(WXDC), amountToWithdraw, address(this));
        WXDC.withdraw(amountToWithdraw);
        _safeTransferXDC(to, amountToWithdraw);
    }

    function _safeTransferXDC(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, "XDC_TRANSFER_FAILED");
    }

    function emergencyTokenTransfer(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    function emergencyXdcTransfer(address to, uint256 amount) external onlyOwner {
        _safeTransferXDC(to, amount);
    }

    function getWXDCAddress() external view returns (address) {
        return address(WXDC);
    }

    receive() external payable {
        require(msg.sender == address(WXDC), "Receive not allowed");
    }

    fallback() external payable {
        revert("Fallback not allowed");
    }
}
