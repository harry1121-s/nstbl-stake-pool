// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "forge-std/console.sol";

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
        if (numOfDays % 2 == 0) {
            loanManager.updateAwaitingRedemption(USDC, true);
        }
        amount_ = bound(amount_, 1e18, 1e32);

        bool awaitingRedemption = loanManager.getAwaitingRedemptionStatus(USDC);

        uint256 oldTime = block.timestamp;
        vm.warp(block.timestamp + numOfDays * 1 days);
        assertEq(block.timestamp, oldTime + numOfDays * 1 days);

        // Action
        uint256 oldPoolBalance = stakePool.poolBalance();
        uint256 oldTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 maturityVal = stakePool.oldMaturityVal();

        stakePool.updatePoolFromHub(false, 0, amount_);
        uint256 newPoolBalance = stakePool.poolBalance();
        uint256 newTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 newMaturityVal = stakePool.oldMaturityVal();

        // // Post-condition
        if (awaitingRedemption) {
            assertEq(newTokenBalance, oldTokenBalance, "1:Should not have minted any rewards to the pool");
            assertEq(newPoolBalance, oldPoolBalance, "1:Pool balance should not have changed");
            assertEq(
                stakePool.oldMaturityVal(), maturityVal + amount_, "1:Should have set the oldMaturityVal correctly"
            );
            loanManager.updateInvestedAssets(loanManager.getMaturedAssets(USDC) + amount_);
            return;
        }
        // // @TODO: test this
        // if(stakePool.oldMaturityVal() < loanManager.getMaturedAssets(USDC)) {
        //     assertEq(newTokenBalance, oldTokenBalance, "2:Should not have minted any rewards to the pool");
        //     assertEq(stakePool.oldMaturityVal(), maturityVal + amount_, "2:Should have set the oldMaturityVal correctly");
        //     return;
        // }

        if (oldPoolBalance <= 1e18) {
            assertEq(
                newTokenBalance - oldTokenBalance,
                newMaturityVal - maturityVal - amount_,
                "3:Rewards minted correctly when poolBalance < 1e18"
            );
            assertEq(newPoolBalance, oldPoolBalance, "3:Pool balance should not have changed");
            assertEq(
                newMaturityVal,
                loanManager.getMaturedAssets(USDC) + amount_,
                "3:Should have set the oldMaturityVal correctly"
            );
            loanManager.updateInvestedAssets(loanManager.getMaturedAssets(USDC) + amount_);
            return;
        }
        // @TODO stake condition
        // uint256 nstblYield = loanManager.getMaturedAssets(USDC) + amount_ - maturityVal;
        // assertEq(newMaturityVal, loanManager.getMaturedAssets(USDC) + amount_, "4:Should have set the oldMaturityVal correctly");

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
        amount_ = amount_ % oldLMAssets + 1;

        // Update loanManager InvestedAssets based on redeem (assumes requestRedemption and Redemption done in one step)
        loanManager.removeAssets(amount_);

        // Action
        uint256 oldPoolBalance = stakePool.poolBalance();
        uint256 oldTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 maturityVal = stakePool.oldMaturityVal();

        stakePool.updatePoolFromHub(true, amount_, 0);
        uint256 newPoolBalance = stakePool.poolBalance();
        uint256 newTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
        uint256 newMaturityVal = stakePool.oldMaturityVal();

        // uint256 nstblYield = (loanManager.getMaturedAssets(USDC) + amount_) - maturityVal;
        // uint256 atvlBal = IERC20Helper(atvl).balanceOf(address(stakePool));
        // uint256 poolBalance = stakePool.poolBalance();
        // uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);

        // Post-condition
        // @TODO: test this
        // if(stakePool.oldMaturityVal() < loanManager.getMaturedAssets(USDC)) {
        //     assertEq(newTokenBalance, oldTokenBalance, "2:Should not have minted any rewards to the pool");
        //     assertEq(stakePool.oldMaturityVal(), maturityVal + amount_, "2:Should have set the oldMaturityVal correctly");
        //     return;
        // }
        if (oldPoolBalance <= 1e18) {
            assertEq(
                newTokenBalance - oldTokenBalance,
                (newMaturityVal + amount_) - maturityVal,
                "Rewards minted correctly when poolBalance < 1e18"
            );
            assertEq(newPoolBalance, oldPoolBalance, "3:Pool balance should not have changed");
            assertEq(
                newMaturityVal, loanManager.getMaturedAssets(USDC), "3:Should have set the oldMaturityVal correctly"
            );
            return;
        }
        // assertEq(newBalance - oldBalance, nstblYield - atvlYield, "Rewards minted correctly to the stakePool");
        // assertEq(stakePool.oldMaturityVal(), loanManager.getMaturedAssets(USDC) , "Should have set the oldMaturityVal correctly");
    }

    function burnNSTBL(uint256 amount_) public { }
}
