// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
import { HandlerBase } from "./helpers/HandlerBase.t.sol";
import { IHandlerMain } from "./helpers/IHandlerMain.sol";

import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
import { NSTBLToken } from "@nstbl-token/contracts/NSTBLToken.sol";
import { LoanManagerMock } from "../../../../contracts/mocks/LoanManagerMock.sol";
import { IStakePool } from "../../../../contracts/IStakePool.sol";

contract HandlerStaker is HandlerBase {
    NSTBLToken public nSTBLtoken;
    NSTBLStakePool public stakePool;
    LoanManagerMock public loanManager;
    IHandlerMain handlerMain;

    uint256 public WARP_RANGE = 10;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public supply;
    address public atvl;

    IStakePool.StakerInfo public stakerInfo;

    constructor(address _token, address _stakePool, address _loanManager, address _handlerMain, address _atvl) {
        nSTBLtoken = NSTBLToken(_token);
        stakePool = NSTBLStakePool(_stakePool);
        loanManager = LoanManagerMock(_loanManager);
        handlerMain = IHandlerMain(_handlerMain);
        atvl = _atvl;
    }

    function stake(uint256 amount_) public {
        // Pre-condition
        uint256 numOfDays = uint256(keccak256(abi.encodePacked(amount_))) % WARP_RANGE + 1; // 1 - 10
        if (numOfDays % 2 == 0) {
            loanManager.updateAwaitingRedemption(USDC, true);
        }

        uint8 trancheId = uint8(amount_ % 3);
        amount_ = bound(amount_, 10e18, 1e32);

        bool awaitingRedemption = loanManager.getAwaitingRedemptionStatus(USDC);

        uint256 oldTime = block.timestamp;
        vm.warp(block.timestamp + numOfDays * 1 days);
        assertLt(trancheId, 3);
        assertGt(block.timestamp, oldTime);
        assertEq(block.timestamp, oldTime + numOfDays * 1 days);
        
        // Action
        uint256 oldPoolBalance = stakePool.poolBalance();
        uint256 oldTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 maturityVal = stakePool.oldMaturityVal();

        deal(address(nSTBLtoken), address(this), amount_);
        nSTBLtoken.approve(address(stakePool), amount_);
        stakePool.stake(address(this), amount_, trancheId, address(this));
        // uint256 newPoolBalance = stakePool.poolBalance();
        // uint256 newTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
        // uint256 newMaturityVal = stakePool.oldMaturityVal();

        (stakerInfo.amount, stakerInfo.poolDebt, stakerInfo.epochId, stakerInfo.lpTokens) =
            stakePool.getStakerInfo(address(this), trancheId);
    }

    function unstake() public { }

}
