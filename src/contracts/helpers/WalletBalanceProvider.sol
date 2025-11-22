// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Address} from "../dependencies/openzeppelin/contracts/Address.sol";
import {IERC20} from "../dependencies/openzeppelin/contracts/IERC20.sol";

import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../interfaces/IPool.sol";
import {SafeERC20} from "../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {ReserveConfiguration} from "../protocol/libraries/configuration/ReserveConfiguration.sol";
import {DataTypes} from "../protocol/libraries/types/DataTypes.sol";

contract WalletBalanceProvider {
    using Address for address payable;
    using Address for address;
    using SafeERC20 for IERC20;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    address constant MOCK_XDC_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function balanceOf(address user, address token) public view returns (uint256) {
        if (token == MOCK_XDC_ADDRESS) {
            return user.balance;
        } else if (token.isContract()) {
            return IERC20(token).balanceOf(user);
        }
        revert("INVALID_TOKEN");
    }

    function batchBalanceOf(address[] calldata users, address[] calldata tokens)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory balances = new uint256[](users.length * tokens.length);

        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                balances[i * tokens.length + j] = balanceOf(users[i], tokens[j]);
            }
        }

        return balances;
    }

    function getUserWalletBalances(address provider, address user)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        IPool pool = IPool(IPoolAddressesProvider(provider).getPool());

        address[] memory reserves = pool.getReservesList();
        address[] memory reservesWithXdc = new address[](reserves.length + 1);
        for (uint256 i = 0; i < reserves.length; i++) {
            reservesWithXdc[i] = reserves[i];
        }
        reservesWithXdc[reserves.length] = MOCK_XDC_ADDRESS;

        uint256[] memory balances = new uint256[](reservesWithXdc.length);

        for (uint256 j = 0; j < reserves.length; j++) {
            DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(reservesWithXdc[j]);

            (bool isActive,,,) = configuration.getFlags();

            if (!isActive) {
                balances[j] = 0;
                continue;
            }
            balances[j] = balanceOf(user, reservesWithXdc[j]);
        }
        balances[reserves.length] = balanceOf(user, MOCK_XDC_ADDRESS);

        return (reservesWithXdc, balances);
    }
}
