// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreditifyV3TokensProcedure} from '../../../contracts/procedures/CreditifyV3TokensProcedure.sol';

contract CreditifyV3TokensBatch is CreditifyV3TokensProcedure {
  TokensReport internal _tokensReport;

  constructor(address poolProxy, address rewardsControllerProxy, address treasury) {
    _tokensReport = _deployCreditifyV3TokensImplementations(poolProxy, rewardsControllerProxy, treasury);
  }

  function getTokensReport() external view returns (TokensReport memory) {
    return _tokensReport;
  }
}
