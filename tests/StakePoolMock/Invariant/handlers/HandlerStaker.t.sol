// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
import { HandlerBase } from "./helpers/HandlerBase.t.sol";
import { IHandlerMain } from "./helpers/IHandlerMain.sol";

contract HandlerStaker is HandlerBase {
    NSTBLStakePool public stakePool;
    IHandlerMain handlerMain;
    uint256 public supply;

    constructor(address _stakePool, address _handlerMain) {
        stakePool = NSTBLStakePool(_stakePool);
        handlerMain = IHandlerMain(_handlerMain);
    }

    function stake() public {
    } 

    function unstake() public {}

    function mint() public {}

}


