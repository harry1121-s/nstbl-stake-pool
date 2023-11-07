// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../helpers/BaseTest.t.sol";
import "../../../contracts/IStakePool.sol";

contract StakePoolTest is BaseTest {
    using SafeERC20 for IERC20Helper;
    
    function setUp() public override {
        super.setUp();
    }
    // function test_stake_singleUser() external {
    //     uint256 _amount = 40 * 1e18;
    //     uint8 _trancheId = 1;

    //     // Action
    //     _stakeNSTBL(user1, _amount, _trancheId);

    //     // Post-condition
    //     assertEq(stakePool.poolBalance(), _amount, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
    //     (uint256 amount, uint256 poolDebt,) = stakePool.getStakerInfo(user1, _trancheId);
    //     assertEq(amount, _amount, "check stakerInfo.amount");
    //     assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");
    //     // _checkStakePostCondition(_stakeId, _trancheId, NSTBL_HUB, _amount, rewardDebt, rewardDebt, block.timestamp);
    // }

    function test_stake_TwoUser(uint256 _amount1, uint256 _amount2, uint256 _investAmount) external {
        
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, type(uint256).max / 1e32);
        _amount1 = _amount1/1e5 * 1e5;
        _amount2 = bound(_amount2, lowerBound, type(uint256).max / 1e32);
        _amount2 = _amount2/1e5 * 1e5;
        _investAmount = bound(_investAmount, lowerBound*2, type(uint256).max / 1e32);
        _investAmount = _investAmount/1e5 * 1e5;
        uint8 _trancheId = 1;

        // Action
        _stakeNSTBL(user1, _amount1, _trancheId);

        // Post-condition
        assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        (uint256 amount, uint256 poolDebt,) = stakePool.getStakerInfo(user1, _trancheId);
        assertEq(amount, _amount1, "check stakerInfo.amount");
        assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

        loanManager.updateInvestedAssets(_investAmount);
        stakePool.updateMaturyValue();

        vm.warp(block.timestamp + 12 days);
        uint8 _trancheId2 = 2;
        // Action
        _stakeNSTBL(user2, _amount2, _trancheId2);

        // Post-condition
        if((loanManager.getMaturedAssets(usdc)-_investAmount) <= (_amount1)*90/1000)
        {
            assertEq(stakePool.poolBalance(), _amount1 + _amount2 + (loanManager.getMaturedAssets(usdc)-_investAmount), "check poolBalance1");
        }
        else {
            assertEq(stakePool.poolBalance(), _amount1 + _amount2 + (_amount1)*9*1e12/1e14, "check poolBalance2");
        }
        (amount, poolDebt,) = stakePool.getStakerInfo(user2, _trancheId2);
        assertEq(amount, _amount2, "check stakerInfo.amount");

        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 poolProductBefore = stakePool.poolProduct();
        uint256 poolEpochIdBefore = stakePool.poolEpochId();

        vm.startPrank(NSTBL_HUB);
        stakePool.unstake(user1, _trancheId, false);
        stakePool.unstake(user2, _trancheId2, false);
        vm.stopPrank();

        uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        uint256 poolProductAfter = stakePool.poolProduct();
        uint256 poolEpochIdAfter = stakePool.poolEpochId();

        console.log("dgdfsghjgfdfdg");
        assertEq(hubBalAfter-hubBalBefore, poolBalBefore-poolBalAfter, "dfsgfg");
        console.log(poolBalAfter, stakePool.atvlExtraYield(), "checking");
        // assertEq(poolProductAfter, 1e18);


        // assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");
    }

    // function test_sequence1() public {
    //     uint256 _amount = 40 * 1e18;
    //     uint8 _trancheId = 1;
    //     uint256 _amount2 = 60 * 1e18;
    //     uint8 _trancheId2 = 2;

    //     _stakeNSTBL(user1, _amount, _trancheId);
    //     _stakeNSTBL(user2, _amount2, _trancheId2);

    //     loanManager.updateInvestedAssets(100 * 1e18);
    //     stakePool.updateMaturyValue();
    //     vm.warp(block.timestamp + 365 days);
    //     stakePool.updatePool();
    //     assertEq(stakePool.poolBalance(), _amount+_amount2+(loanManager.getMaturedAssets(usdc)-100*1e18), "check poolBalance");
    //     assertEq(stakePool.poolProduct(), (1e18*(1e18+(loanManager.getMaturedAssets(usdc)*1e18-100*1e36)/1e20))/1e18);

    //     vm.startPrank(NSTBL_HUB);
    //     stakePool.burnNSTBL(10 * 1e18);
    //     vm.stopPrank();

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     stakePool.unstake(user1, _trancheId, false); //  only user1 unstakes
    //     uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     vm.stopPrank();

    //     (uint256 amount, uint256 poolDebt,) = stakePool.getStakerInfo(user2, _trancheId2);
    //     assertEq(hubBalAfter-hubBalBefore, poolBalBefore-poolBalAfter);
    //     assertEq(stakePool.poolBalance(), amount*stakePool.poolProduct()/1e18, "check poolBalance");

    //     (amount, poolDebt,) = stakePool.getStakerInfo(user1, _trancheId);
    //     assertEq(amount, 0, "check stakerInfo.amount");
    //     assertEq(poolDebt, 0, "check stakerInfo.poolDebt");
    //     console.log("poolBalance after", stakePool.poolBalance());
    //     console.log("poolProduct after", stakePool.poolProduct());
    //     //user3 new yield event
    //     vm.warp(block.timestamp + 100 days);

    //     _stakeNSTBL(user3, 10 * 1e18, 0);
    //     ( amount, poolDebt,) = stakePool.getStakerInfo(user3, 0);
    //     assertEq(stakePool.poolProduct(), poolDebt, "check stakerInfo.poolDebt"); // user3 gets 0 yield
    //     ( uint256 amountUser2, uint256 poolDebtUser2,) = stakePool.getStakerInfo(user2, _trancheId2);
    //     assertTrue(stakePool.poolBalance()-(amountUser2*stakePool.poolProduct()/poolDebtUser2 + amount) < 1e2, "check poolBalance"); //all the yield goes to user 2; creates a 10^-2 precision error

    //     console.log("poolBalance before ustake-------------", stakePool.poolBalance());
    //     //unstaking both user2 and user3
    //     vm.startPrank(NSTBL_HUB);
    //     stakePool.unstake(user2, _trancheId2, false);
    //     stakePool.unstake(user3, 0, false);
    //     vm.stopPrank();
        
    //     //the pool is drained, so system values should reset
    //     assertEq(stakePool.poolBalance(), 0, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        




    // }

    // function test_sequence1_fuzz(uint256 _amount1, uint256 _amount2, uint256 _amount3, uint256 _investAmount, uint256 _burnAmount) public {
    //     uint256 lowerBound = 10 * 1e18;
    //     _amount1 = bound(_amount1, lowerBound, type(uint256).max / 1e32);
    //     _amount2 = bound(_amount2, lowerBound, type(uint256).max / 1e32);
    //     _amount3 = bound(_amount3, lowerBound, type(uint256).max / 1e32);
    //     _investAmount = bound(_investAmount, lowerBound*5, type(uint256).max / 1e32);
    //     _burnAmount = bound(_burnAmount, lowerBound, type(uint256).max / 1e32);
    //     uint8 _trancheId = 1;
    //     uint8 _trancheId2 = 2;

    //     _stakeNSTBL(user1, _amount1, _trancheId);
    //     _stakeNSTBL(user2, _amount2, _trancheId2);

    //     loanManager.updateInvestedAssets(_investAmount);
    //     stakePool.updateMaturyValue();
    //     vm.warp(block.timestamp + 365 days);
    //     stakePool.updatePool();
        
    //     // vm.startPrank(NSTBL_HUB);
    //     // stakePool.burnNSTBL(_burnAmount);
    //     // vm.stopPrank();

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     stakePool.unstake(user1, _trancheId, false); //  only user1 unstakes
    //     uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     vm.stopPrank();

    //     (uint256 amount, uint256 poolDebt,) = stakePool.getStakerInfo(user2, _trancheId2);
    //     assertEq(hubBalAfter-hubBalBefore, poolBalBefore-poolBalAfter);
    //     assertApproxEqAbs(stakePool.poolBalance(), amount*stakePool.poolProduct()/1e18, 1e6, "check poolBalance");

    //     // (amount, poolDebt,) = stakePool.getStakerInfo(user1, _trancheId);
    //     // assertTrue(amount<1e2, "check stakerInfo.amount");
    //     // // assertEq(poolDebt, 0, "check stakerInfo.poolDebt");
    //     // console.log("poolBalance after", stakePool.poolBalance());
    //     // console.log("poolProduct after", stakePool.poolProduct());
    //     // //user3 new yield event
    //     // vm.warp(block.timestamp + 100 days);

    //     // _stakeNSTBL(user3, _amount3, 0);
    //     // ( amount, poolDebt,) = stakePool.getStakerInfo(user3, 0);
    //     // assertEq(stakePool.poolProduct(), poolDebt, "check stakerInfo.poolDebt"); // user3 gets 0 yield
    //     // ( uint256 amountUser2, uint256 poolDebtUser2,) = stakePool.getStakerInfo(user2, _trancheId2);
    //     // assertApproxEqAbs(stakePool.poolBalance(), (amountUser2*stakePool.poolProduct()/poolDebtUser2 + amount), 1e2, "check poolBalance"); //all the yield goes to user 2; creates a 10^-2 precision error

    //     // console.log("poolBalance before ustake-------------", stakePool.poolBalance());
    //     // //unstaking both user2 and user3
    //     // vm.startPrank(NSTBL_HUB);
    //     // stakePool.unstake(user2, _trancheId2, false);
    //     // stakePool.unstake(user3, 0, false);
    //     // vm.stopPrank();
        
    //     // //the pool is drained, so system values should reset
    //     // assertApproxEqAbs(stakePool.poolBalance(), 0, 1e5, "check poolBalance");
    //     // // assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

    // }

    // function test_stake_singleUser_fuzz(uint256 _amount, bytes11 _stakeId, uint8 _trancheId, uint256 _share) external {
    //     // Pre-condition
    //     _amount = bound(_amount, 1, type(uint256).max / 1e32);
    //     _share = bound(_share, 1, 1e32);
    //     _trancheId = uint8(bound(_trancheId, 0, 3));

    //     // Action
    //     vm.store(address(stakePool), bytes32(uint256(3)), bytes32(uint256(_share)));
    //     vm.store(address(stakePool), bytes32(uint256(4)), bytes32(uint256(_share)));
    //     _stakeNSTBL(_amount, _stakeId, _trancheId);

    //     // Post-condition
    //     uint256 rewardDebt = (_amount * stakePool.accNSTBLPerShare()) / 1e18;
    //     _checkStakePostCondition(_stakeId, _trancheId, NSTBL_HUB, _amount, rewardDebt, rewardDebt, block.timestamp);
    //     assertEq(stakePool.totalStakedAmount(), _amount, "check totalStakedAmount");
    // }

    // https://www.somacon.com/p568.php (use to check repition of random number)
    // function testRandom() external {
    //     bytes11 _stakeId = bytes11(0x1122334455667788991122);
    //     uint256 len = 50;

    //     bytes11[] memory stakeIds = new bytes11[](len);
    //     uint[] memory index = new uint[](len);
    //     for(uint256 i = 0; i < len; i++) {
    //         (_stakeId, index[i]) = _randomizeStakeIdAndIndex(_stakeId, len);
    //         stakeIds[i] = _stakeId;
    //     }
    //     // for(uint256 i = 0; i < len; i++) {
    //     //     console.logBytes11(stakeIds[i]);
    //     // }
    //     // for(uint256 i = 0; i < len; i++) {
    //     //     console.log(index[i]);
    //     // }

    //     vm.store(address(stakePool), bytes32(uint256(3)), bytes32(uint256(3)));
    //     console.log(stakePool.accNSTBLPerShare());
    // }

    // function test_stake_multipleUsers_fuzz(uint256 _amount, bytes11 _stakeId, uint256 _share) external {
    //     // Pre-condition
    //     _amount = bound(_amount, 1, type(uint256).max / 1e32);
    //     _share = bound(_share, 1e18, 5e18);
    //     uint256 upperBound = 5;

    //     bytes11[] memory stakeIds = new bytes11[](upperBound);
    //     uint[] memory index = new uint[](upperBound);
    //     for(uint256 i = 0; i < upperBound; i++) {
    //         (_stakeId, index[i]) = _randomizeStakeIdAndIndex(_stakeId, upperBound);
    //         stakeIds[i] = _stakeId;
    //     }

    //     for(uint256 i = 0; i < upperBound; i++) {
    //         (,,,
    //         uint256 amount,
    //         uint256 rewardDebt,
    //         uint256 burnDebt,
    //         ) = stakePool.stakerInfo(stakeIds[index[i]]);
    //         _share *= 2;

    //         // Action
    //         vm.store(address(stakePool), bytes32(uint256(3)), bytes32(uint256(_share)));
    //         _stakeNSTBL(_amount, stakeIds[index[i]], uint8(_amount % 3));
            
    //         uint256 debt = (_amount * _share) / 1e18;

    //         if(amount == 0) {
    //             // Check Condition
    //             _checkStakePostCondition(stakeIds[index[i]], uint8(_amount % 3), NSTBL_HUB, _amount, debt, 0, block.timestamp);
    //         }
    //         else {
    //             // Check Condition
    //             debt = burnDebt + (amount * _share / 1e18);
    //             debt = amount + debt - (amount *  stakePool.burnNSTBLPerShare()/ 1e18 + rewardDebt);
    //             debt += _amount;
    //             uint256 debt2 = (debt * stakePool.accNSTBLPerShare()) / 1e18;
    //             _checkStakePostCondition(stakeIds[index[i]], uint8(_amount % 3), NSTBL_HUB, debt, debt2, 0, block.timestamp);
    //         }
            
    //     }
    // }

    // function test_updatePool() external {
    //     uint256 _amount = 10_000_000 * 1e18;
    //     bytes11 _stakeId = bytes11(0x1122334455667788991122);
    //     uint8 _trancheId = 0;

    //     // Action
    //     _stakeNSTBL(user1, _amount, _trancheId);
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     stakePool.updateMaturyValue();
    //     vm.warp(block.timestamp + 12 days);
    //     loanManager.updateAwaitingRedemption(usdc, true);

    //     // Mocking for updatePool when awaiting redemption is active
    //     uint256 oldVal = stakePool.oldMaturityVal();
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
    //     stakePool.updatePool();
    //     assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption"); 
    //     assertEq(stakePool.poolProduct(), 1e18, "No update due to awaiting redemption");
    //     assertEq(stakePool.poolBalance(), 10_000_000 * 1e18, "No update due to awaiting redemption");

    //     // // Mocking for updatePool when awaiting redemption is inactive
    //     // oldVal = stakePool.oldMaturityVal();
    //     // loanManager.updateAwaitingRedemption(usdc, false);
    //     // assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
    //     // stakePool.updatePool();
    //     // uint256 newVal = stakePool.oldMaturityVal();
    //     // assertEq(newVal-oldVal, loanManager.getMaturedAssets(usdc) - 15e5*1e18, "UpdateRewards");

    //     // // Mocking for updatePool when tBills are devalued
    //     // loanManager.updateInvestedAssets(10e5 * 1e18);
    //     // vm.warp(block.timestamp + 12 days);
    //     // oldVal = stakePool.oldMaturityVal();
    //     // stakePool.updatePool();
    //     // newVal = stakePool.oldMaturityVal();
    //     // assertEq(newVal, oldVal, "No reward update due to Maple devalue");
        
    // }

    //  function test_updatePool_fuzz(uint256 _amount, bytes11 _stakeId, uint256 _time) external {
    //     // Pre-condition
    //     _amount = bound(_amount, 1, type(uint256).max / 1e32);
    //     _time = bound(_time, 0, 100 days);
    //     uint8 _trancheId = uint8(_amount % 3);


    //     // Action
    //     _stakeNSTBL(_amount, _stakeId, _trancheId);

    //     loanManager.updateInvestedAssets(_amount * 4);

    //     stakePool.updateMaturyValue();
    //     vm.warp(block.timestamp + _time);
    //     loanManager.updateAwaitingRedemption(usdc, true);

    //     // Mocking for updatePool when awaiting redemption is active
    //     uint256 oldVal = stakePool.oldMaturityVal();
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
    //     stakePool.updatePool();
    //     assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption"); 
    //     assertEq(stakePool.accNSTBLPerShare(), 0, "No update due to awaiting redemption");

    //     // Mocking for updatePool when awaiting redemption is inactive
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(usdc, false);
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
    //     stakePool.updatePool();
    //     uint256 newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal-oldVal, loanManager.getMaturedAssets(usdc) - _amount * 4, "UpdateRewards");

    //     // Mocking for updatePool when tBills are devalued
    //     loanManager.updateInvestedAssets(_amount * 3);
    //     vm.warp(block.timestamp + _time);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePool();
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal, "No reward update due to Maple devalue");


        


    //     // Post-condition
    //     // uint256 rewardDebt = (_amount * stakePool.accNSTBLPerShare()) / 1e18;
    //     // _checkStakePostCondition(_stakeId, _trancheId, NSTBL_HUB, _amount, rewardDebt, rewardDebt, block.timestamp);
    //     // assertEq(stakePool.totalStakedAmount(), _amount, "check totalStakedAmount");
    // }

    // function test_updatePoolFromHub() external {
    //     uint256 _amount = 10_000_000 * 1e18;
    //     bytes11 _stakeId = bytes11(0x1122334455667788991122);
    //     uint8 _trancheId = 0;

    //     // Action
    //     _stakeNSTBL(_amount, _stakeId, _trancheId);
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     stakePool.updateMaturyValue();
    //     vm.warp(block.timestamp + 12 days);
    //     loanManager.updateAwaitingRedemption(usdc, true);

    //     // Mocking for updatePoolFromHub during deposit when awaiting redemption is active
    //     vm.startPrank(NSTBL_HUB);
    //     uint256 oldVal = stakePool.oldMaturityVal();
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
    //     stakePool.updatePoolFromHub(false, 0, 1e6*1e18);
    //     assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption"); 
    //     assertEq(stakePool.accNSTBLPerShare(), 0, "No update due to awaiting redemption");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during deposit when awaiting redemption is inactive
    //     vm.startPrank(NSTBL_HUB);
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(usdc, false);
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
    //     stakePool.updatePoolFromHub(false, 0, 1e6*1e18);
    //     uint256 newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal-oldVal, loanManager.getMaturedAssets(usdc) - 15e5*1e18 + 1e6*1e18, "UpdateRewards");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active
    //     loanManager.updateInvestedAssets(15e5 * 1e18 + 1e6*1e18);
    //     vm.warp(block.timestamp + 12 days);
    //     vm.startPrank(NSTBL_HUB);
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(usdc, true);
    //     stakePool.updatePoolFromHub(true, 1e3*1e18, 0);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal-oldVal, loanManager.getMaturedAssets(usdc)-oldVal, "Reward update due to redemption");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active and tBills are devalued
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.warp(block.timestamp + 12 days);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePoolFromHub(true, 1e3*1e18, 0);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal, "No reward update due to ,aple devalue");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during deposit when tBills are devalued
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateAwaitingRedemption(usdc, true);
    //     vm.warp(block.timestamp + 12 days);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePoolFromHub(false, 0, 1e6*1e18);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal, "No reward update due to Maple devalue");
    //     vm.stopPrank();

    // }

    // function test_updatePoolFromHub_fuzz(uint256 _amount, bytes11 _stakeId, uint256 _time) external {
        
    //     _amount = bound(_amount, 100, type(uint256).max / 1e32);
    //     _time = bound(_time, 0, 100 days);
    //     uint8 _trancheId = uint8(_amount % 3);

    //     // Action
    //     _stakeNSTBL(_amount, _stakeId, _trancheId);
    //     loanManager.updateInvestedAssets(_amount*4);
    //     stakePool.updateMaturyValue();
    //     vm.warp(block.timestamp + _time);
    //     loanManager.updateAwaitingRedemption(usdc, true);

    //     // Mocking for updatePoolFromHub during deposit when awaiting redemption is active
    //     vm.startPrank(NSTBL_HUB);
    //     uint256 oldVal = stakePool.oldMaturityVal();
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
    //     stakePool.updatePoolFromHub(false, 0, _amount/10);
    //     assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption"); 
    //     assertEq(stakePool.accNSTBLPerShare(), 0, "No update due to awaiting redemption");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during deposit when awaiting redemption is inactive
    //     vm.startPrank(NSTBL_HUB);
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(usdc, false);
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
    //     stakePool.updatePoolFromHub(false, 0, _amount/10);
    //     uint256 newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal-oldVal, loanManager.getMaturedAssets(usdc) - _amount*4 + _amount/10, "UpdateRewards");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active
    //     loanManager.updateInvestedAssets(_amount*4 + _amount/10);
    //     vm.warp(block.timestamp + _time);
    //     vm.startPrank(NSTBL_HUB);
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(usdc, true);
    //     stakePool.updatePoolFromHub(true, _amount/100, 0);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal-oldVal, loanManager.getMaturedAssets(usdc)-oldVal, "Reward update due to redemption");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active and tBills are devalued
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateInvestedAssets(_amount*4);
    //     vm.warp(block.timestamp + _time);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePoolFromHub(true, _amount/100, 0);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal, "No reward update due to ,aple devalue");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during deposit when tBills are devalued
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateAwaitingRedemption(usdc, true);
    //     vm.warp(block.timestamp + _time);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePoolFromHub(false, 0, _amount/10);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal, "No reward update due to Maple devalue");
    //     vm.stopPrank();

    // }
    // function test_unstake_singleUser() external {

    //     //precision is lost at 1e3
    //     uint256 amount = 1e6 * 1e18;

    //     _stakeNSTBL(amount, 0, user1);
    //     console.log("-----------------------------------------");
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.warp(block.timestamp + 12 days);

    //     assertEq(stakePool.getUserStakedAmount(user1, 0), amount);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

    //     console.log("2nd staking");
    //     _stakeNSTBL(amount, 0, user1);
    //     // stakePool.updatePools();
    //     console.log("-----------------------------------------");
    //     (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
    //     uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

    //     vm.startPrank(NSTBL_HUB);
    //     console.log("-----------------------------------------");
    //     vm.warp(block.timestamp + 500 days);
    //     (uint256 availableTokens,) = stakePool.getUserAvailableTokensDepeg(user1, 0);
    //     console.log("Available Tokens", availableTokens);
    //     uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     stakePool.unstake(user1, 0, true);
    //     // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(nealthyBalAfter-nealthyBalBefore, availableTokens);
    //     uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     vm.stopPrank();

    //     // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

    //     console.log("-----------------------------------------");
    //     console.log("Total Staked Amount", stakePool.totalStakedAmount());
    //     console.log("Remaining Pool balance", poolBalAfter);
    //     console.log("ATVL yield", stakePool.atvlExtraYield());
    //     // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());

    // }

    // function test_unstake_singleUser_singlePool_singleStake_fuzz(uint256 _amount1) external {

    //     uint256 stakeUpperBound =
    //         (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
    //     _amount1 = bound(_amount1, 1e3, stakeUpperBound);

    //      _stakeNSTBL(_amount1, 0, user1);
    //     console.log("-----------------------------------------");
    //     loanManager.updateInvestedAssets(15e5 * 1e18);

    //     vm.warp(block.timestamp + 12 days);
    //     stakePool.updatePools();
    //     assertEq(stakePool.getUserStakedAmount(user1, 0), _amount1);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

    //     (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
    //     uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

    //     vm.startPrank(NSTBL_HUB);

    //     stakePool.unstake(user1, 0, false);
    //     assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     vm.stopPrank();
    //     // (,,,,,,uint256 poolTokens) = stakePool.getPoolInfo(0);

    //     assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));
    //     // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield()); due to precision lost at 1e3
    // }

    // function test_unstake_MultiplePools() external {

    //     _stakeNSTBL(1e6 * 1e18, 0, user1);
    //     _stakeNSTBL(1e6 * 1e18, 1, user2);
    //     _stakeNSTBL(1e6 * 1e18, 2, user3);

    //     loanManager.updateInvestedAssets(10e6 * 1e18);
    //     vm.warp(block.timestamp + 300 days);

    //     (,,uint256 yield) = stakePool.getUpdatedYieldParams();
    //     uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(nstblToken.balanceOf(address(stakePool)), 3e6 * 1e18);
    //     assertEq(stakePool.totalStakedAmount(), 3e6 * 1e18);

    //     console.log("Updating Pools");
    //     stakePool.updatePools();
    //     _stakeNSTBL(1e6 * 1e18, 0, user1);

    //     (uint256 user1UnstakeAmount,) = stakePool.previewUnstake(stakePool.getUserStakedAmount(user1, 0), user1, 0);
    //     console.log(user1UnstakeAmount);

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 user1StakeAmt = stakePool.getUserStakedAmount(user1, 0);
    //     stakePool.unstake(user1, 0, false);
    //     uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(user1StakeAmt*950/1000, user1UnstakeAmount);
    //     assertEq(nealthyBalAfter-nealthyBalBefore, user1UnstakeAmount);
    //     assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     vm.stopPrank();
    //     console.log("----------------------------------------------------------------------1");
    //     _stakeNSTBL(1e6*1e18, 1, user1);

    //     vm.warp(block.timestamp + 30 days);
    //     stakePool.updatePools();
    //     (user1UnstakeAmount,) = stakePool.previewUnstake(stakePool.getUserStakedAmount(user1, 1), user1, 1);
    //     (uint256 user2Rewards,) = stakePool.previewUnstake(stakePool.getUserStakedAmount(user2, 1), user2, 1);
    //     console.log("----------------------------------------------------------------------2");

    //     nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     vm.startPrank(NSTBL_HUB);
    //     user1StakeAmt = stakePool.getUserStakedAmount(user1, 1);
    //     stakePool.unstake(user1, 1, false);
    //     nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(nealthyBalAfter-nealthyBalBefore, user1UnstakeAmount);
    //     assertEq(stakePool.getUserStakedAmount(user1, 1), 0);

    //     nealthyBalBefore = nealthyBalAfter;
    //     uint256 user2StakeAmt = stakePool.getUserStakedAmount(user2, 1);
    //     stakePool.unstake(user2, 1, false);
    //     nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(nealthyBalAfter-nealthyBalBefore, user2Rewards);
    //     assertEq(stakePool.getUserStakedAmount(user2, 1), 0);
    //     vm.stopPrank();

    // }

    // function test_unstake_MultiplePools_fuzz(uint256 _amount1, uint256 _amount2, uint256 _amount3) external {

    //     uint256 stakeUpperBound =
    //         (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
    //     _amount1 = bound(_amount1, 1, stakeUpperBound-2);
    //     // console.log("UpperBound", stakeUpperBound);
    //     _stakeNSTBL(_amount1, 0, user1);

    //     stakeUpperBound =
    //         (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
    //     _amount2 = bound(_amount2, 1, stakeUpperBound-1);
    //     // console.log("UpperBound", stakeUpperBound);
    //     _stakeNSTBL(_amount2, 1, user2);

    //     stakeUpperBound =
    //         (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
    //     // console.log("UpperBound", stakeUpperBound);
    //     _amount3 = bound(_amount3, 1, stakeUpperBound);
    //     _stakeNSTBL(_amount3, 2, user3);

    //     loanManager.updateInvestedAssets(1e30);
    //     vm.warp(block.timestamp + 300 days);

    //     assertEq(nstblToken.balanceOf(address(stakePool)), _amount1+_amount2+_amount3);
    //     assertEq(stakePool.totalStakedAmount(), _amount1+_amount2+_amount3);

    //     uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     (uint256 user1UnstakeAmount,) = stakePool.previewUnstake(_amount1, user1, 0);
    //     console.log(user1UnstakeAmount);

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 user1StakeAmt = stakePool.getUserStakedAmount(user1, 0);
    //     console.log("-----------------------------------------------1");
    //     stakePool.unstake(user1, 0, false);
    //     console.log("-----------------------------------------------2");
    //     uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     console.log(user1UnstakeAmount, nealthyBalAfter, nealthyBalBefore);
    //     assertEq(user1UnstakeAmount, nealthyBalAfter-nealthyBalBefore);
    //     assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     vm.stopPrank();

    //     nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     (uint256 user2UnstakeAmount,) = stakePool.previewUnstake(_amount2, user2, 1);
    //     console.log(user2UnstakeAmount);

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 user2StakeAmt = stakePool.getUserStakedAmount(user2, 1);
    //     console.log("-----------------------------------------------3");
    //     stakePool.unstake(user2, 1, false);
    //     console.log("-----------------------------------------------3");
    //     nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(user2UnstakeAmount, nealthyBalAfter-nealthyBalBefore);
    //     assertEq(stakePool.getUserStakedAmount(user2, 1), 0);
    //     vm.stopPrank();

    //     vm.warp(block.timestamp + 300 days);
    //     // stakePool.updatePools();
    //     console.log("dfgsdfgsgfsdhgggfgfggggggggggggggg");
    //     nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     (uint256 user3UnstakeAmount,) = stakePool.previewUnstake(_amount3, user3, 2);

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 user3StakeAmt = stakePool.getUserStakedAmount(user3, 2);
    //     console.log("-----------------------------------------------5");
    //     stakePool.unstake(user3, 2, false);
    //     console.log("-----------------------------------------------6");
    //     nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(user3UnstakeAmount, nealthyBalAfter-nealthyBalBefore);
    //     assertEq(stakePool.getUserStakedAmount(user3, 2), 0);
    //     vm.stopPrank();

    // }

    // function test_unstake_burnNstbl_singleUser() external {
    //     //precision is lost at 1e3
    //     uint256 amount = 1e6 * 1e18;

    //     _stakeNSTBL(amount, 0, user1);
    //     console.log("-----------------------------------------");
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.warp(block.timestamp + 12 days);

    //     assertEq(stakePool.getUserStakedAmount(user1, 0), amount);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

    //     console.log("Burning NSTBL");
    //     vm.prank(NSTBL_HUB);
    //     stakePool.burnNstbl(1e24);

    //     console.log("2nd staking");
    //     _stakeNSTBL(amount, 0, user1);
    //     // stakePool.updatePools();
    //     console.log("-----------------------------------------");
    //     // (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
    //     // uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     // uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

    //     // vm.startPrank(NSTBL_HUB);
    //     // console.log("-----------------------------------------");

    //     // stakePool.unstake(user1, 0, false);
    //     // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     // uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     // vm.stopPrank();

    //     // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

    //     // console.log("-----------------------------------------");
    //     // console.log("Total Staked Amount", stakePool.totalStakedAmount());
    //     // console.log("Remaining Pool balance", poolBalAfter);
    //     // console.log("ATVL yield", stakePool.atvlExtraYield());
    //     // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());
    // }

    // function test_unstake_burnNstbl_singleUser_fuzz(uint256 _amount) external {
    //     //precision is lost at 1e3
    //     uint256 amount = 1e6 * 1e18;

    //     _stakeNSTBL(amount, 0, user1);
    //     console.log("-----------------------------------------");
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.warp(block.timestamp + 12 days);

    //     assertEq(stakePool.getUserStakedAmount(user1, 0), amount);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

    //     console.log("Burning NSTBL");
    //     vm.startPrank(NSTBL_HUB);
    //     console.log("REVERT PARAMS: ", _amount, nstblToken.balanceOf(address(stakePool)));
    //     if(_amount > nstblToken.balanceOf(address(stakePool)) + stakePool.getAvailableYield())
    //         vm.expectRevert("SP:: Burn amount exceeds staked amount");
    //     stakePool.burnNstbl(_amount);
    //     vm.stopPrank();

    //     console.log("2nd staking");
    //     _stakeNSTBL(amount, 0, user1);
    //     // stakePool.updatePools();
    //     console.log("-----------------------------------------");
    //     // (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
    //     // uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     // uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

    //     // vm.startPrank(NSTBL_HUB);
    //     // console.log("-----------------------------------------");

    //     // stakePool.unstake(user1, 0, false);
    //     // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     // uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     // vm.stopPrank();

    //     // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

    //     // console.log("-----------------------------------------");
    //     // console.log("Total Staked Amount", stakePool.totalStakedAmount());
    //     // console.log("Remaining Pool balance", poolBalAfter);
    //     // console.log("ATVL yield", stakePool.atvlExtraYield());
    //     // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());
    // }
    // function test_unstake_burnNstbl_TwoUser_fuzz(uint256 _amount) external {
    //     //precision is lost at 1e3
    //     uint256 amount = 1e6 * 1e18;

    //     _stakeNSTBL(amount/2, 0, user1);
    //     _stakeNSTBL(amount/2, 1, user2);
    //     _stakeNSTBL(amount, 1, user3);
    //     console.log("-----------------------------------------");
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.warp(block.timestamp + 12 days);

    //     assertEq(stakePool.getUserStakedAmount(user1, 0), amount/2);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

    //     console.log("Burning NSTBL");
    //     vm.startPrank(NSTBL_HUB);
    //     if(_amount > nstblToken.balanceOf(address(stakePool)))
    //         vm.expectRevert("SP:: Burn amount exceeds staked amount");
    //     stakePool.burnNstbl(_amount);
    //     vm.stopPrank();

    //     console.log("2nd staking");
    //     _stakeNSTBL(amount, 0, user1);
    //     _stakeNSTBL(amount, 1, user2);
    //     // stakePool.updatePools();
    //     console.log("-----------------------------------------");
    //     // (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
    //     // uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     // uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

    //     // vm.startPrank(NSTBL_HUB);
    //     // console.log("-----------------------------------------");

    //     // stakePool.unstake(user1, 0, false);
    //     // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
    //     // uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     // vm.stopPrank();

    //     // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

    //     // console.log("-----------------------------------------");
    //     // console.log("Total Staked Amount", stakePool.totalStakedAmount());
    //     // console.log("Remaining Pool balance", poolBalAfter);
    //     // console.log("ATVL yield", stakePool.atvlExtraYield());
    //     // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());
    // }

    // function test_updateYieldParams() external {
    //     _stakeNSTBL(1e6 * 1e18, 0, user1);

    //     loanManager.updateInvestedAssets(10e6 * 1e18);

    //     vm.warp(block.timestamp + 30 days);

    //     console.log("-------------case 1------------");
    //     uint256 nstblBalBefore = nstblToken.balanceOf(address(stakePool));
    //     uint256 a;
    //     uint256 b1;
    //     uint256 b2;
    //     uint256 b3;
    //     uint256 c;
    //     (a, b1, c) = stakePool.getUpdatedYieldParams();

    //     assertEq(a, loanManager.getInvestedAssets(usdc));
    //     assertEq(loanManager.getMaturedAssets(usdc), b1);
    //     console.log(b1-a, c);

    //     assertEq(stakePool.usdcInvestedAmount(), 0);
    //     assertEq(stakePool.usdcMaturityAmount(), 0);

    //     stakePool.updatePools();
    //     uint256 nstblBalAfter = nstblToken.balanceOf(address(stakePool));

    //     assertEq(stakePool.usdcInvestedAmount(), a);
    //     assertEq(stakePool.usdcMaturityAmount(), b1);
    //     assertEq(c, nstblBalAfter-nstblBalBefore);

    //     vm.warp(block.timestamp + 30 days);

    //     console.log("-------------case 2--------------");
    //     (a, b2, c) = stakePool.getUpdatedYieldParams();
    //     // loanManager.rebalanceInvestedAssets();
    //     assertEq(a, loanManager.getInvestedAssets(usdc));
    //     assertEq(loanManager.getMaturedAssets(usdc), b2);
    //     assertEq(b2-stakePool.usdcMaturityAmount(), c);

    //     assertEq(stakePool.usdcInvestedAmount(), a);
    //     assertEq(stakePool.usdcMaturityAmount(), b1);
    //     nstblBalBefore = nstblToken.balanceOf(address(stakePool));
    //     stakePool.updatePools();
    //     nstblBalAfter = nstblToken.balanceOf(address(stakePool));

    //     assertEq(stakePool.usdcInvestedAmount(), a);
    //     assertEq(stakePool.usdcMaturityAmount(), b2);
    //     assertEq(c, nstblBalAfter-nstblBalBefore);

    //     loanManager.addAssets(1e6 * 1e18);
    //     console.log("Amount Before: ", a);

    //     console.log("-------------case 3--------------");
    //     (a, b3, c) = stakePool.getUpdatedYieldParams();

    //     console.log("Amount After: ", a);
    //     assertEq(a, loanManager.getInvestedAssets(usdc));
    //     assertEq(loanManager.getMaturedAssets(usdc), b3);
    //     assertEq(b3-stakePool.usdcMaturityAmount()- (a-stakePool.usdcInvestedAmount()), c);

    //     assertEq(a-stakePool.usdcInvestedAmount(), 1e6*1e18);
    //     assertEq(b3-stakePool.usdcMaturityAmount(), 1e6*1e18);

    //     nstblBalBefore = nstblToken.balanceOf(address(stakePool));
    //     stakePool.updatePools();
    //     nstblBalAfter = nstblToken.balanceOf(address(stakePool));
    //     // // loanManager.rebalanceInvestedAssets();

    //     assertEq(stakePool.usdcInvestedAmount(), a);
    //     assertEq(stakePool.usdcMaturityAmount(), b3);
    //     assertEq(c, nstblBalAfter-nstblBalBefore);

    //     console.log("-------------case 4--------------");

    //     loanManager.rebalanceInvestedAssets();
    //     stakePool.updatePools();
    //     assertEq(stakePool.usdcMaturityAmount(), loanManager.getMaturedAssets(usdc));

    //     console.log("removing from rebalanced state");
    //     loanManager.removeAssets(3e6 * 1e18);
    //     loanManager.rebalanceInvestedAssets();

    //     // console.log(loanManager.getMaturedAssets(usdc));

    //     (a, b3, c) = stakePool.getUpdatedYieldParams();

    //     console.log("Before");
    //     uint256 beforeInv = stakePool.usdcInvestedAmount();
    //     uint256 beforeMat = stakePool.usdcMaturityAmount();

    //     console.log(a,b3,c);

    //     nstblBalBefore = nstblToken.balanceOf(address(stakePool));
    //     stakePool.updatePools();
    //     nstblBalAfter = nstblToken.balanceOf(address(stakePool));

    //     assertEq(a, beforeInv-3e6*1e18);
    //     assertEq(b3, beforeMat*8e24/11e24);
    //     assertEq(c, nstblBalAfter-nstblBalBefore);

    // }
}
