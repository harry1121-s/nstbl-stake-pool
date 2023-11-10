// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { HandlerBase } from "./helpers/HandlerBase.t.sol";
import { IHandlerMain } from "./helpers/IHandlerMain.sol";

import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
import { NSTBLToken } from "@nstbl-token/contracts/NSTBLToken.sol";
import { LoanManagerMock } from "../../../../contracts/mocks/LoanManagerMock.sol";
import { IERC20Helper } from "../../../../contracts/StakePoolStorage.sol";

contract HandlerHub is HandlerBase {
    NSTBLToken public nSTBLtoken;
    NSTBLStakePool public stakePool;
    LoanManagerMock public loanManager;
    IHandlerMain handlerMain;

    uint256 public WARP_RANGE = 10;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public supply;
    address public atvl;
    
    constructor(address _token, address _stakePool, address _loanManager, address _handlerMain, address _atvl) {
        nSTBLtoken = NSTBLToken(_token);
        stakePool = NSTBLStakePool(_stakePool);
        loanManager = LoanManagerMock(_loanManager);
        handlerMain = IHandlerMain(_handlerMain);
        atvl = _atvl;
    }

    function deposit(uint256 amount_) public {
        // Pre-condition
        uint256 numOfDays = uint256(keccak256(abi.encodePacked(amount_))) % WARP_RANGE + 1; // 1 - 10
        if(numOfDays % 2 == 0) {
            loanManager.updateAwaitingRedemption(USDC, true);
        }
        amount_ = amount_ % 1e32;
        
        bool awaitingRedemption = loanManager.getAwaitingRedemptionStatus(USDC);

        uint256 oldTime = block.timestamp;
        vm.warp(block.timestamp + numOfDays * 1 days); 
        assertEq(block.timestamp, oldTime + numOfDays * 1 days);

        uint256 oldBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 maturityVal = stakePool.oldMaturityVal();

        // Action
        stakePool.updatePoolFromHub(false, 0, amount_);
        uint256 newBalance = nSTBLtoken.balanceOf(address(stakePool));

        // Post-condition
        if(!awaitingRedemption) {
            assertEq(newBalance - oldBalance, loanManager.getMaturedAssets(USDC) - maturityVal, "Rewards minted correctly");
        }
        else {
            assertEq(newBalance - oldBalance, 0, "Should not have minted any rewards to the pool");
            assertEq(stakePool.oldMaturityVal(), maturityVal + amount_, "Should have set the oldMaturityVal correctly");
        }

        // Update loanManager InvestedAssets based on deposit
        loanManager.updateInvestedAssets(loanManager.getMaturedAssets(USDC) + amount_);
    }

    function redeemMaple(uint256 amount_) public {
        // Pre-condition
        uint256 numOfDays = uint256(keccak256(abi.encodePacked(amount_))) % WARP_RANGE + 1; // 1 - 10

        // Increase Time
        uint256 oldTime = block.timestamp;
        vm.warp(block.timestamp + numOfDays * 1 days); 
        assertEq(block.timestamp, oldTime + numOfDays * 1 days);

        // Redemption less than assets invested in Maple
        uint256 oldLMAssets = loanManager.getMaturedAssets(USDC);
        amount_ = amount_ % oldLMAssets;

        // Update loanManager InvestedAssets based on redeem (assumes requestRedemption and Redemption done in one step)
        loanManager.updateInvestedAssets(oldLMAssets - amount_);

        uint256 oldBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 maturityVal = stakePool.oldMaturityVal();

        // Action
        stakePool.updatePoolFromHub(true, amount_, 0);
        // uint256 newBalance = nSTBLtoken.balanceOf(address(stakePool));

        // uint256 nstblYield = loanManager.getMaturedAssets(USDC) + amount_ - maturityVal;
        // uint256 atvlBal = IERC20Helper(atvl).balanceOf(address(stakePool));
        // uint256 poolBalance = stakePool.poolBalance();
        // uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);
        // // Post-condition
        // assertEq(newBalance - oldBalance, nstblYield - atvlYield, "Rewards minted correctly to the stakePool");
        // assertEq(stakePool.oldMaturityVal(), loanManager.getMaturedAssets(USDC) , "Should have set the oldMaturityVal correctly");

    }



}


