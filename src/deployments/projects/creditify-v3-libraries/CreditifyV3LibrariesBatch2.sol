// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/LibraryReportStorage.sol";
import {Create2Utils} from "../../contracts/utilities/Create2Utils.sol";

import {LiquidationLogic} from "../../../contracts/protocol/libraries/logic/LiquidationLogic.sol";
import {PoolLogic} from "../../../contracts/protocol/libraries/logic/PoolLogic.sol";
import {SupplyLogic} from "../../../contracts/protocol/libraries/logic/SupplyLogic.sol";

contract CreditifyV3LibrariesBatch2 is LibraryReportStorage {
    constructor() {
        _librariesReport = _deployCreditifyV3Libraries();
    }

    function _deployCreditifyV3Libraries() internal returns (LibrariesReport memory libReport) {
        bytes32 salt = keccak256("CREDITIFY_V3_LIBRARIES_BATCH");

        libReport.liquidationLogic = Create2Utils._create2Deploy(salt, type(LiquidationLogic).creationCode);
        libReport.poolLogic = Create2Utils._create2Deploy(salt, type(PoolLogic).creationCode);
        libReport.supplyLogic = Create2Utils._create2Deploy(salt, type(SupplyLogic).creationCode);
        return libReport;
    }
}
