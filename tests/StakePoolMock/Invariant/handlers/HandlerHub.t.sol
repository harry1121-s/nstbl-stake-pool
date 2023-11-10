// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { HandlerBase } from "./helpers/HandlerBase.t.sol";
import { IHandlerMain } from "./helpers/IHandlerMain.sol";

import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
import { NSTBLToken } from "@nstbl-token/contracts/NSTBLToken.sol";
import { LoanManagerMock } from "../../../../contracts/mocks/LoanManagerMock.sol";

contract HandlerHub is HandlerBase {
    NSTBLToken public nSTBLtoken;
    NSTBLStakePool public stakePool;
    LoanManagerMock public loanManager;
    IHandlerMain handlerMain;

    uint256 public WARP_RANGE = 10;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public supply;
    
    constructor(address _token, address _stakePool, address _loanManager, address _handlerMain) {
        nSTBLtoken = NSTBLToken(_token);
        stakePool = NSTBLStakePool(_stakePool);
        loanManager = LoanManagerMock(_loanManager);
        handlerMain = IHandlerMain(_handlerMain);
    }

    function deposit(uint256 amount_) public {
        // Pre-condition
        uint256 numOfDays = uint256(keccak256(abi.encodePacked(amount_))) % WARP_RANGE + 1; // 1 - 10
        amount_ = amount_ % 1e32;

        bool awaitingRedemption = loanManager.getAwaitingRedemptionStatus(USDC);

        uint256 oldTime = block.timestamp;
        vm.warp(block.timestamp + numOfDays * 1 days); 
        assertEq(block.timestamp, oldTime + numOfDays * 1 days);

        uint256 oldLMVal = loanManager.getMaturedAssets(USDC);
        uint256 oldBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 maturityVal = stakePool.oldMaturityVal();

        // Action
        stakePool.updatePoolFromHub(false, amount_, 0);
        uint256 newBalance = nSTBLtoken.balanceOf(address(stakePool));

        // Post-condition
        if(!awaitingRedemption)
        assertEq(newBalance - oldBalance, loanManager.getMaturedAssets(USDC) - maturityVal);
        else
        

        loanManager.updateInvestedAssets(loanManager.getMaturedAssets(USDC) + oldLMVal);
    }

    function redeem() public {

    }



}


