// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.21;

// import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
// import { HandlerBase } from "./helpers/HandlerBase.t.sol";
// import { IHandlerMain } from "./helpers/IHandlerMain.sol";

// import { NSTBLStakePool } from "../../../../contracts/StakePool.sol";
// import { NSTBLToken } from "@nstbl-token/contracts/NSTBLToken.sol";
// import { LoanManagerMock } from "../../../../contracts/mocks/LoanManagerMock.sol";
// import { IStakePool } from "../../../../contracts/IStakePool.sol";

// contract HandlerStaker is HandlerBase {
//     NSTBLToken public nSTBLtoken;
//     NSTBLStakePool public stakePool;
//     LoanManagerMock public loanManager;
//     IHandlerMain handlerMain;

//     uint256 public WARP_RANGE = 10;
//     address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//     uint256 public supply;
//     address public atvl;

//     IStakePool.StakerInfo public stakerInfo;
//     IStakePool.StakerInfo public stakerInfoNew;

//     uint32 public trancheBaseFee1;
//     uint32 public trancheBaseFee2;
//     uint32 public trancheBaseFee3;

//     uint32 public earlyUnstakeFee1;
//     uint32 public earlyUnstakeFee2;
//     uint32 public earlyUnstakeFee3;
//     mapping(uint8 => uint64) public trancheStakeTimePeriod;

//     constructor(address _token, address _stakePool, address _loanManager, address _handlerMain, address _atvl) {
//         nSTBLtoken = NSTBLToken(_token);
//         stakePool = NSTBLStakePool(_stakePool);
//         loanManager = LoanManagerMock(_loanManager);
//         handlerMain = IHandlerMain(_handlerMain);
//         atvl = _atvl;
//     }

//     function stake(uint256 amount_) public {
//         // Pre-condition
//         uint256 numOfDays = bound(amount_, 1 days, 10 days);
//         if (numOfDays % 2 == 0) {
//             loanManager.updateAwaitingRedemption(USDC, true);
//         }

//         uint8 trancheId = uint8(amount_ % 3);
//         assertLt(trancheId, 3);
//         amount_ = bound(amount_, 10e18, 1e30);

//         bool awaitingRedemption = loanManager.getAwaitingRedemptionStatus(USDC);

//         // Action
//         uint256 oldPoolBalance = stakePool.poolBalance();
//         uint256 oldTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
//         uint256 maturityVal = stakePool.oldMaturityVal();
//         uint256 oldPoolProduct = stakePool.poolProduct();

//         (stakerInfo.amount, stakerInfo.poolDebt, stakerInfo.epochId, stakerInfo.lpTokens, stakerInfo.stakeTimeStamp) =
//             stakePool.getStakerInfo(address(this), trancheId);

//         uint256 unstakeFee;
//         if (stakerInfo.amount > 0) {
//             uint256 tokensAvailable = (stakerInfo.amount * oldPoolProduct) / stakerInfo.poolDebt;
//             unstakeFee = _getUnstakeFee(trancheId, stakerInfo.stakeTimeStamp) * tokensAvailable / 10_000;
//         }

//         deal(address(nSTBLtoken), address(this), amount_);
//         nSTBLtoken.approve(address(stakePool), amount_);
//         stakePool.stake(address(this), amount_, trancheId, address(this));
//         _setFees();

//         uint256 newPoolBalance = stakePool.poolBalance();
//         uint256 newTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
//         uint256 newMaturityVal = stakePool.oldMaturityVal();
//         (
//             stakerInfoNew.amount,
//             stakerInfoNew.poolDebt,
//             stakerInfoNew.epochId,
//             stakerInfoNew.lpTokens,
//             stakerInfoNew.stakeTimeStamp
//         ) = stakePool.getStakerInfo(address(this), trancheId);

//         // Post-condition
//         if (stakerInfo.amount == 0) {
//             // First stake
//             assertEq(stakerInfoNew.amount, amount_, "1:Should have staked the correct amount");
//             assertEq(stakerInfoNew.poolDebt, stakePool.poolProduct(), "1:Should have set the poolDebt correctly");
//             assertEq(stakerInfoNew.epochId, stakePool.poolEpochId(), "1:Should have set the epochId correctly");
//             assertEq(stakerInfoNew.lpTokens, amount_, "1:Should have set the lpTokens correctly");
//         } else {
//             if (loanManager.getAwaitingRedemptionStatus(USDC)) {
//                 assertEq(
//                     stakerInfoNew.amount,
//                     stakerInfo.amount + amount_ - unstakeFee,
//                     "2:Should have staked the correct amount"
//                 );
//                 assertEq(stakerInfoNew.poolDebt, stakePool.poolProduct(), "2:Should have set the poolDebt correctly");
//                 assertEq(stakerInfoNew.epochId, stakerInfo.epochId, "2:Should have set the epochId correctly");
//                 assertEq(
//                     stakerInfoNew.lpTokens, stakerInfo.lpTokens + amount_, "2:Should have set the lpTokens correctly"
//                 );
//             }
//         }
//         // Updating staker details
//         (stakerInfo.amount, stakerInfo.poolDebt, stakerInfo.epochId, stakerInfo.lpTokens, stakerInfo.stakeTimeStamp) =
//             stakePool.getStakerInfo(address(this), trancheId);
//         uint256 oldTime = block.timestamp;
//         vm.warp(block.timestamp + numOfDays);
//     }

//     function unstake(uint256 amount_) public {
//         // Pre-condition
//         uint256 numOfDays = bound(amount_, 1 days, 10 days);
//         bool depeg;
//         if (numOfDays % 2 == 0) {
//             loanManager.updateAwaitingRedemption(USDC, true);
//             depeg = true;
//         }
//         uint8 trancheId = uint8(amount_ % 3);
//         assertLt(trancheId, 3);
//         amount_ = bound(amount_, 10e18, 1e30);

//         bool awaitingRedemption = loanManager.getAwaitingRedemptionStatus(USDC);

//         // uint256 tokenBalanceStaker =
//         uint256 oldPoolBalance = stakePool.poolBalance();
//         uint256 oldTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
//         uint256 maturityVal = stakePool.oldMaturityVal();
//         uint256 oldPoolProduct = stakePool.poolProduct();

//         (stakerInfo.amount, stakerInfo.poolDebt, stakerInfo.epochId, stakerInfo.lpTokens, stakerInfo.stakeTimeStamp) =
//             stakePool.getStakerInfo(address(this), trancheId);

//         // Action
//         if (stakerInfo.amount == 0) {
//             vm.expectRevert();
//             stakePool.unstake(address(this), trancheId, depeg, address(this));
//             return;
//         }

//         stakePool.unstake(address(this), trancheId, depeg, address(this));
//         _setFees();
//         uint256 newPoolBalance = stakePool.poolBalance();
//         uint256 newTokenBalance = nSTBLtoken.balanceOf(address(stakePool));
//         uint256 newMaturityVal = stakePool.oldMaturityVal();
//         (
//             stakerInfoNew.amount,
//             stakerInfoNew.poolDebt,
//             stakerInfoNew.epochId,
//             stakerInfoNew.lpTokens,
//             stakerInfoNew.stakeTimeStamp
//         ) = stakePool.getStakerInfo(address(this), trancheId);

//         uint256 tokensAvailable = (stakerInfo.amount * oldPoolProduct) / stakerInfo.poolDebt;
//         uint256 unstakeFee;
//         if (!depeg) {
//             unstakeFee = _getUnstakeFee(trancheId, stakerInfo.stakeTimeStamp) * tokensAvailable / 10_000;
//         }
//         assertEq(stakerInfoNew.amount, 0, "1:Should have unstaked the correct amount");
//         assertEq(stakerInfoNew.epochId, 0, "1:Should have set the epochId correctly");
//         // Updating staker details
//         (stakerInfo.amount, stakerInfo.poolDebt, stakerInfo.epochId, stakerInfo.lpTokens, stakerInfo.stakeTimeStamp) =
//             stakePool.getStakerInfo(address(this), trancheId);
//         uint256 oldTime = block.timestamp;
//         vm.warp(block.timestamp + numOfDays);
//     }

//     function _setFees() internal {
//         trancheBaseFee1 = stakePool.trancheBaseFee1();
//         trancheBaseFee2 = stakePool.trancheBaseFee2();
//         trancheBaseFee3 = stakePool.trancheBaseFee3();

//         earlyUnstakeFee1 = stakePool.earlyUnstakeFee1();
//         earlyUnstakeFee2 = stakePool.earlyUnstakeFee2();
//         earlyUnstakeFee3 = stakePool.earlyUnstakeFee3();

//         trancheStakeTimePeriod[0] = stakePool.trancheStakeTimePeriod(0);
//         trancheStakeTimePeriod[1] = stakePool.trancheStakeTimePeriod(1);
//         trancheStakeTimePeriod[2] = stakePool.trancheStakeTimePeriod(2);
//     }

//     function _getUnstakeFee(uint8 _trancheId, uint256 _stakeTimeStamp) internal view returns (uint256 fee) {
//         uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
//         if (_trancheId == 0) {
//             fee = (timeElapsed > trancheStakeTimePeriod[0])
//                 ? trancheBaseFee1
//                 : trancheBaseFee1
//                     + (earlyUnstakeFee1 * (trancheStakeTimePeriod[0] - timeElapsed) / trancheStakeTimePeriod[0]);
//         } else if (_trancheId == 1) {
//             fee = (timeElapsed > trancheStakeTimePeriod[1])
//                 ? trancheBaseFee2
//                 : trancheBaseFee2
//                     + (earlyUnstakeFee2 * (trancheStakeTimePeriod[1] - timeElapsed) / trancheStakeTimePeriod[1]);
//         } else {
//             fee = (timeElapsed > trancheStakeTimePeriod[2])
//                 ? trancheBaseFee3
//                 : trancheBaseFee3
//                     + (earlyUnstakeFee3 * (trancheStakeTimePeriod[2] - timeElapsed) / trancheStakeTimePeriod[2]);
//         }
//     }
// }
