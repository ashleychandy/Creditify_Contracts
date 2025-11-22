// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/LibraryReportStorage.sol";
import {Create2Utils} from "../../contracts/utilities/Create2Utils.sol";
import {BorrowLogic} from "../../../contracts/protocol/libraries/logic/BorrowLogic.sol";
import {ConfiguratorLogic} from "../../../contracts/protocol/libraries/logic/ConfiguratorLogic.sol";

contract CreditifyV3LibrariesBatch1 is LibraryReportStorage {
    constructor() {
        _librariesReport = _deployCreditifyV3Libraries();
    }

    function _deployCreditifyV3Libraries() internal returns (LibrariesReport memory libReport) {
        bytes32 salt = keccak256("CREDITIFY_V3_LIBRARIES_BATCH");

        libReport.borrowLogic = Create2Utils._create2Deploy(salt, type(BorrowLogic).creationCode);
        libReport.configuratorLogic = Create2Utils._create2Deploy(salt, type(ConfiguratorLogic).creationCode);
        return libReport;
    }
}
