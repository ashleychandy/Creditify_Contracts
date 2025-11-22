// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IStakedToken} from "../interfaces/IStakedToken.sol";
import {ITransferStrategyBase} from "./ITransferStrategyBase.sol";

interface IStakedTokenTransferStrategy is ITransferStrategyBase {
    function renewApproval() external;

    function dropApproval() external;

    function getStakeContract() external view returns (address);

    function getUnderlyingToken() external view returns (address);
}
