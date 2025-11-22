// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ATokenInstance} from "../../../contracts/instances/ATokenInstance.sol";
import {VariableDebtTokenInstance} from "../../../contracts/instances/VariableDebtTokenInstance.sol";
import {IPool} from "../../../contracts/interfaces/IPool.sol";
import {ICreditifyIncentivesController} from "../../../contracts/interfaces/ICreditifyIncentivesController.sol";

contract CreditifyV3TokensProcedure {
    struct TokensReport {
        address aToken;
        address variableDebtToken;
    }

    function _deployCreditifyV3TokensImplementations(
        address poolProxy,
        address rewardsControllerProxy,
        address treasury
    ) internal returns (TokensReport memory) {
        TokensReport memory tokensReport;

        ATokenInstance aToken = new ATokenInstance(IPool(poolProxy), rewardsControllerProxy, treasury);
        VariableDebtTokenInstance variableDebtToken =
            new VariableDebtTokenInstance(IPool(poolProxy), rewardsControllerProxy);

        tokensReport.aToken = address(aToken);
        tokensReport.variableDebtToken = address(variableDebtToken);

        return tokensReport;
    }
}
