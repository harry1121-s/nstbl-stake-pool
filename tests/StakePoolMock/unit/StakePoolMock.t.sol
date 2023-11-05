// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../helpers/BaseTest.t.sol";

contract StakePoolTest is BaseTest {
    using SafeERC20 for IERC20Helper;

    function setUp() public override {
        super.setUp();
    }

    function test_stake_singleUser_singlePool_fuzz(uint256 _amount1) external {
        uint256 stakeUpperBound =
            (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
        _amount1 = bound(_amount1, 1, stakeUpperBound);
        _stakeNstbl(_amount1, 0, user1);

        assertEq(stakePool.totalStakedAmount(), _amount1);
        assertEq(stakePool.getUserStakedAmount(user1, 0), _amount1);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);
    }

    function test_stake_multiUser_multiPool_fuzz(uint256 _amount1, uint256 _amount2, uint256 _amount3, uint256 _amount4)
        external
    {
        uint256 stakeUpperBound =
            (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
        _amount1 = bound(_amount1, 1, stakeUpperBound / 3);
        _amount2 = bound(_amount2, 1, stakeUpperBound / 3);
        _amount3 = bound(_amount3, 1, stakeUpperBound / 3);
        _amount4 = bound(_amount4, stakeUpperBound, stakeUpperBound * 2);
        // vm.assume(_amount1+_amount2+_amount3 <= stakeUpperBound);
        _stakeNstbl(_amount1, 0, user1);
        _stakeNstbl(_amount2, 1, user2);
        _stakeNstbl(_amount3, 2, user3);

        loanManager.updateInvestedAssets(_amount4);

        assertEq(stakePool.totalStakedAmount(), _amount1 + _amount2 + _amount3);
        assertEq(stakePool.getUserStakedAmount(user1, 0), _amount1);
        assertEq(stakePool.getUserStakedAmount(user2, 1), _amount2);
        assertEq(stakePool.getUserStakedAmount(user3, 2), _amount3);
    }

    function test_unstake_singleUser() external {

        //precision is lost at 1e3
        uint256 amount = 1e6 * 1e18;

        _stakeNstbl(amount, 0, user1);
        console.log("-----------------------------------------");
        loanManager.updateInvestedAssets(15e5 * 1e18);
        vm.warp(block.timestamp + 12 days);

        assertEq(stakePool.getUserStakedAmount(user1, 0), amount);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

        console.log("2nd staking");
        _stakeNstbl(amount, 0, user1);
        // stakePool.updatePools();
        console.log("-----------------------------------------");
        (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
        uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        vm.startPrank(NSTBL_HUB);
        console.log("-----------------------------------------");
        vm.warp(block.timestamp + 500 days);
        stakePool.unstake(user1, 0, false);
        // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
        uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        vm.stopPrank();

        // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

        console.log("-----------------------------------------");
        console.log("Total Staked Amount", stakePool.totalStakedAmount());
        console.log("Remaining Pool balance", poolBalAfter);
        console.log("ATVL yield", stakePool.atvlExtraYield());
        // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());

    }

    function test_unstake_singleUser_singlePool_singleStake_fuzz(uint256 _amount1) external {

        uint256 stakeUpperBound =
            (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
        _amount1 = bound(_amount1, 1e3, stakeUpperBound);

         _stakeNstbl(_amount1, 0, user1);
        console.log("-----------------------------------------");
        loanManager.updateInvestedAssets(15e5 * 1e18);

        vm.warp(block.timestamp + 12 days);
        stakePool.updatePools();
        assertEq(stakePool.getUserStakedAmount(user1, 0), _amount1);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

        (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
        uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        vm.startPrank(NSTBL_HUB);

        stakePool.unstake(user1, 0, false);
        assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
        uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        vm.stopPrank();
        // (,,,,,,uint256 poolTokens) = stakePool.getPoolInfo(0);

        assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));
        // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield()); due to precision lost at 1e3
    }

    // function test_unstake_MultiplePools() external {

    //     _stakeNstbl(1e6 * 1e18, 0, user1);
    //     _stakeNstbl(1e6 * 1e18, 1, user2);
    //     _stakeNstbl(1e6 * 1e18, 2, user3);

    //     loanManager.updateInvestedAssets(10e6 * 1e18);
    //     vm.warp(block.timestamp + 300 days);

    //     (,,uint256 yield) = stakePool.getUpdatedYieldParams();
    //     uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(nstblToken.balanceOf(address(stakePool)), 3e6 * 1e18);
    //     assertEq(stakePool.totalStakedAmount(), 3e6 * 1e18);

    //     console.log("Updating Pools");
    //     stakePool.updatePools();
    //     _stakeNstbl(1e6 * 1e18, 0, user1);

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
    //     _stakeNstbl(1e6*1e18, 1, user1);

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
    //     _stakeNstbl(_amount1, 0, user1);

    //     stakeUpperBound =
    //         (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
    //     _amount2 = bound(_amount2, 1, stakeUpperBound-1);
    //     // console.log("UpperBound", stakeUpperBound);
    //     _stakeNstbl(_amount2, 1, user2);

    //     stakeUpperBound =
    //         (stakePool.stakingThreshold() * nstblToken.totalSupply() / 10_000) - stakePool.totalStakedAmount();
    //     // console.log("UpperBound", stakeUpperBound);
    //     _amount3 = bound(_amount3, 1, stakeUpperBound);
    //     _stakeNstbl(_amount3, 2, user3);

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

    function test_unstake_burnNstbl_singleUser() external {
        //precision is lost at 1e3
        uint256 amount = 1e6 * 1e18;

        _stakeNstbl(amount, 0, user1);
        console.log("-----------------------------------------");
        loanManager.updateInvestedAssets(15e5 * 1e18);
        vm.warp(block.timestamp + 12 days);

        assertEq(stakePool.getUserStakedAmount(user1, 0), amount);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

        console.log("Burning NSTBL");
        vm.prank(NSTBL_HUB);
        stakePool.burnNstbl(1e24);

        console.log("2nd staking");
        _stakeNstbl(amount, 0, user1);
        // stakePool.updatePools();
        console.log("-----------------------------------------");
        // (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
        // uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        // uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        // vm.startPrank(NSTBL_HUB);
        // console.log("-----------------------------------------");

        // stakePool.unstake(user1, 0, false);
        // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
        // uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        // vm.stopPrank();

        // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

        // console.log("-----------------------------------------");
        // console.log("Total Staked Amount", stakePool.totalStakedAmount());
        // console.log("Remaining Pool balance", poolBalAfter);
        // console.log("ATVL yield", stakePool.atvlExtraYield());
        // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());
    }

    function test_unstake_burnNstbl_singleUser_fuzz(uint256 _amount) external {
        //precision is lost at 1e3
        uint256 amount = 1e6 * 1e18;

        _stakeNstbl(amount, 0, user1);
        console.log("-----------------------------------------");
        loanManager.updateInvestedAssets(15e5 * 1e18);
        vm.warp(block.timestamp + 12 days);

        assertEq(stakePool.getUserStakedAmount(user1, 0), amount);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

        console.log("Burning NSTBL");
        vm.startPrank(NSTBL_HUB);
        console.log("REVERT PARAMS: ", _amount, nstblToken.balanceOf(address(stakePool)));
        if(_amount > nstblToken.balanceOf(address(stakePool)) + stakePool.getAvailableYield())
            vm.expectRevert("SP:: Burn amount exceeds staked amount");
        stakePool.burnNstbl(_amount);
        vm.stopPrank();

        console.log("2nd staking");
        _stakeNstbl(amount, 0, user1);
        // stakePool.updatePools();
        console.log("-----------------------------------------");
        // (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
        // uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        // uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        // vm.startPrank(NSTBL_HUB);
        // console.log("-----------------------------------------");

        // stakePool.unstake(user1, 0, false);
        // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
        // uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        // vm.stopPrank();

        // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

        // console.log("-----------------------------------------");
        // console.log("Total Staked Amount", stakePool.totalStakedAmount());
        // console.log("Remaining Pool balance", poolBalAfter);
        // console.log("ATVL yield", stakePool.atvlExtraYield());
        // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());
    }
    function test_unstake_burnNstbl_TwoUser_fuzz(uint256 _amount) external {
        //precision is lost at 1e3
        uint256 amount = 1e6 * 1e18;

        _stakeNstbl(amount/2, 0, user1);
        _stakeNstbl(amount/2, 1, user2);
        _stakeNstbl(amount, 1, user3);
        console.log("-----------------------------------------");
        loanManager.updateInvestedAssets(15e5 * 1e18);
        vm.warp(block.timestamp + 12 days);

        assertEq(stakePool.getUserStakedAmount(user1, 0), amount/2);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);

        console.log("Burning NSTBL");
        vm.startPrank(NSTBL_HUB);
        if(_amount > nstblToken.balanceOf(address(stakePool)))
            vm.expectRevert("SP:: Burn amount exceeds staked amount");
        stakePool.burnNstbl(_amount);
        vm.stopPrank();

        console.log("2nd staking");
        _stakeNstbl(amount, 0, user1);
        _stakeNstbl(amount, 1, user2);
        // stakePool.updatePools();
        console.log("-----------------------------------------");
        // (,, uint256 nstblYield) = stakePool.getUpdatedYieldParams();
        // uint256 nealthyBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        // uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        // vm.startPrank(NSTBL_HUB);
        // console.log("-----------------------------------------");

        // stakePool.unstake(user1, 0, false);
        // assertEq(stakePool.getUserStakedAmount(user1, 0), 0);
        // uint256 nealthyBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        // vm.stopPrank();

        // assertEq(poolBalBefore + nstblYield - poolBalAfter, (nealthyBalAfter - nealthyBalBefore) + (atvlBalAfter - atvlBalBefore));

        // console.log("-----------------------------------------");
        // console.log("Total Staked Amount", stakePool.totalStakedAmount());
        // console.log("Remaining Pool balance", poolBalAfter);
        // console.log("ATVL yield", stakePool.atvlExtraYield());
        // assertEq(stakePool.getUnclaimedRewards(), poolBalAfter-stakePool.atvlExtraYield());
    }

    function test_updateYieldParams() external {
        _stakeNstbl(1e6 * 1e18, 0, user1);

        loanManager.updateInvestedAssets(10e6 * 1e18);

        vm.warp(block.timestamp + 30 days);

        console.log("-------------case 1------------");
        uint256 nstblBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 a;
        uint256 b1;
        uint256 b2;
        uint256 b3;
        uint256 c;
        (a, b1, c) = stakePool.getUpdatedYieldParams();

        assertEq(a, loanManager.getInvestedAssets(usdc));
        assertEq(loanManager.getMaturedAssets(usdc), b1);
        console.log(b1-a, c);

        assertEq(stakePool.usdcInvestedAmount(), 0);
        assertEq(stakePool.usdcMaturityAmount(), 0);

        stakePool.updatePools();
        uint256 nstblBalAfter = nstblToken.balanceOf(address(stakePool));

        assertEq(stakePool.usdcInvestedAmount(), a);
        assertEq(stakePool.usdcMaturityAmount(), b1);
        assertEq(c, nstblBalAfter-nstblBalBefore);

        vm.warp(block.timestamp + 30 days);

        console.log("-------------case 2--------------");
        (a, b2, c) = stakePool.getUpdatedYieldParams();
        // loanManager.rebalanceInvestedAssets();
        assertEq(a, loanManager.getInvestedAssets(usdc));
        assertEq(loanManager.getMaturedAssets(usdc), b2);
        assertEq(b2-stakePool.usdcMaturityAmount(), c);

        assertEq(stakePool.usdcInvestedAmount(), a);
        assertEq(stakePool.usdcMaturityAmount(), b1);
        nstblBalBefore = nstblToken.balanceOf(address(stakePool));
        stakePool.updatePools();
        nstblBalAfter = nstblToken.balanceOf(address(stakePool));

        assertEq(stakePool.usdcInvestedAmount(), a);
        assertEq(stakePool.usdcMaturityAmount(), b2);
        assertEq(c, nstblBalAfter-nstblBalBefore);

        loanManager.addAssets(1e6 * 1e18);
        console.log("Amount Before: ", a);

        console.log("-------------case 3--------------");
        (a, b3, c) = stakePool.getUpdatedYieldParams();

        console.log("Amount After: ", a);
        assertEq(a, loanManager.getInvestedAssets(usdc));
        assertEq(loanManager.getMaturedAssets(usdc), b3);
        assertEq(b3-stakePool.usdcMaturityAmount()- (a-stakePool.usdcInvestedAmount()), c);

        assertEq(a-stakePool.usdcInvestedAmount(), 1e6*1e18);
        assertEq(b3-stakePool.usdcMaturityAmount(), 1e6*1e18);

        nstblBalBefore = nstblToken.balanceOf(address(stakePool));
        stakePool.updatePools();
        nstblBalAfter = nstblToken.balanceOf(address(stakePool));
        // // loanManager.rebalanceInvestedAssets();

        assertEq(stakePool.usdcInvestedAmount(), a);
        assertEq(stakePool.usdcMaturityAmount(), b3);
        assertEq(c, nstblBalAfter-nstblBalBefore);

        console.log("-------------case 4--------------");

        loanManager.rebalanceInvestedAssets();
        stakePool.updatePools();
        assertEq(stakePool.usdcMaturityAmount(), loanManager.getMaturedAssets(usdc));

        console.log("removing from rebalanced state");
        loanManager.removeAssets(3e6 * 1e18);
        loanManager.rebalanceInvestedAssets();

        // console.log(loanManager.getMaturedAssets(usdc));

        (a, b3, c) = stakePool.getUpdatedYieldParams();

        console.log("Before");
        uint256 beforeInv = stakePool.usdcInvestedAmount();
        uint256 beforeMat = stakePool.usdcMaturityAmount();

        console.log(a,b3,c);

        nstblBalBefore = nstblToken.balanceOf(address(stakePool));
        stakePool.updatePools();
        nstblBalAfter = nstblToken.balanceOf(address(stakePool));

        assertEq(a, beforeInv-3e6*1e18);
        assertEq(b3, beforeMat*8e24/11e24);
        assertEq(c, nstblBalAfter-nstblBalBefore);

    }
}
