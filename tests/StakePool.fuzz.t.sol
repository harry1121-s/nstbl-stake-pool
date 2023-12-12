// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseTest.t.sol";

contract StakePoolTestFuzz is BaseTest {
    using SafeERC20 for IERC20Helper;

    /*//////////////////////////////////////////////////////////////
    Setup
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
    }

    function test_stake_fuzz(uint256 _amount1, uint256 _amount2, uint256 _amount3, uint256 _investAmount, uint256 _time)
        external
    {
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
        _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
        _amount3 = bound(_amount3, lowerBound, 1e12 * 1e18);
        _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
        _time = bound(_time, 10 days, 5 * 365 days); // randomize for all three don't use same time
        // fuzz awaiting redemption
        // write stateless fuzz

        loanManager.updateInvestedAssets(_investAmount);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        _stakeNSTBL(user1, _amount1, 0);
        _stakeNSTBL(user2, _amount2, 1);
        _stakeNSTBL(user3, _amount3, 2);
        assertEq(stakePool.poolBalance(), _amount1 + _amount2 + _amount3, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

        vm.warp(block.timestamp + _time);
        uint256 tokensUser1 = stakePool.getUserAvailableTokens(user1, 0);
        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        _stakeNSTBL(user1, _amount1, 0);
        assertApproxEqRel(
            stakePool.getUserAvailableTokens(user1, 0), (tokensUser1 + _amount1), 1e17, "check user1 available tokens"
        );
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
            assertApproxEqAbs(
                poolBalAfter - poolBalBefore + (atvlBalAfter - atvlBalBefore),
                _amount1 + (loanManager.getMaturedAssets() - _investAmount),
                1e18,
                "with yield"
            );
        } else {
            assertEq(poolBalAfter - poolBalBefore + (atvlBalAfter - atvlBalBefore), _amount1, "without yield");
        }
    }

    function test_unstake_fuzz(uint256 _amount1, uint256 _amount2, uint256 _investAmount, uint256 _time) external {
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
        _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
        _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
        _time = bound(_time, 0, 5 * 365 days);

        loanManager.updateInvestedAssets(_investAmount);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        _stakeNSTBL(user1, _amount1, 0);
        _stakeNSTBL(user2, _amount2, 1);

        vm.warp(block.timestamp + _time);

        vm.startPrank(NSTBL_HUB);
        uint256 balBefore = nstblToken.balanceOf(destinationAddress);
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        stakePool.unstake(user1, 0, false, destinationAddress);
        stakePool.unstake(user2, 1, true, destinationAddress);

        uint256 balAfter = nstblToken.balanceOf(destinationAddress);
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);

        // if (_time / 1 days <= stakePool.trancheStakeTimePeriod(0) + 1) {
        if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
            assertApproxEqAbs(
                balAfter - balBefore + (atvlBalAfter - atvlBalBefore),
                _amount2 + _amount1 + (loanManager.getMaturedAssets() - _investAmount),
                1e18,
                "with yield"
            );
        } else {
            assertEq(balAfter - balBefore + (atvlBalAfter - atvlBalBefore), _amount1 + _amount2, "without yield");
        }
        assertEq(stakePool.poolBalance(), 0);
        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: NO STAKE");
        stakePool.unstake(user3, 0, false, destinationAddress);
        vm.stopPrank();
        vm.warp(block.timestamp + 100 days);
        assertEq(stakePool.previewUpdatePool(), stakePool.poolProduct());
        _stakeNSTBL(user4, 1e3 * 1e18, 1);
    }

    function test_stake_unstake_updatePool_fuzz(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _investAmount,
        uint256 _time
    ) external {
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
        _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
        _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
        // _investAmount = bound(_investAmount, 1e24, 1e15 * 1e18);
        _time = bound(_time, 0, 5 * 365 days);

        loanManager.updateInvestedAssets(_investAmount);
        vm.startPrank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        vm.expectRevert("SP: GENESIS");
        stakePool.updateMaturityValue();
        vm.stopPrank();
        // Action
        deal(address(nstblToken), address(stakePool), 1e24); // just to mess with the system
        _stakeNSTBL(user1, _amount1, 1);

        // Should revert if the amount is zero
        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: ZERO_AMOUNT");
        stakePool.stake(user1, 0, 1);
        vm.stopPrank();

        // Should revert if trancheId is invalid
        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: INVALID_TRANCHE");
        stakePool.stake(user1, 1e3 * 1e18, 3);
        vm.stopPrank();

        // Post-condition
        assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        (uint256 amount, uint256 poolDebt,,) = stakePool.getStakerInfo(user1, 1);
        assertEq(amount, _amount1, "check stakerInfo.amount");
        assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

        vm.warp(block.timestamp + _time);
        // Action
        _stakeNSTBL(user2, _amount2, 2);

        // Post-condition
        if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
            assertEq(
                stakePool.poolBalance(),
                _amount1 + _amount2 + (loanManager.getMaturedAssets() - _investAmount),
                "check poolBalance1"
            );
        } else {
            assertEq(stakePool.poolBalance(), _amount1 + _amount2, "check poolBalance3");
        }

        (amount, poolDebt,,) = stakePool.getStakerInfo(user2, 2);
        assertEq(amount, _amount2, "check stakerInfo.amount");

        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

        vm.startPrank(NSTBL_HUB);
        uint256 balBefore = nstblToken.balanceOf(destinationAddress);

        stakePool.unstake(user1, 1, false, destinationAddress);

        uint256 balAfter = nstblToken.balanceOf(destinationAddress);
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);

        // Post-condition; stakeAmount + all yield transferred
        // if (_time / 1 days <= stakePool.trancheStakeTimePeriod(1) + 1) {
        if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
            assertApproxEqAbs(
                balAfter - balBefore + (atvlBalAfter - atvlBalBefore),
                _amount1 + (loanManager.getMaturedAssets() - _investAmount),
                1e18
            );
        } else {
            assertEq(balAfter - balBefore + (atvlBalAfter - atvlBalBefore), _amount1);
        }

        stakePool.unstake(user2, 2, false, destinationAddress);
        vm.stopPrank();
        atvlBalAfter = nstblToken.balanceOf(atvl);
        balAfter = nstblToken.balanceOf(destinationAddress);
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));

        assertEq(balAfter - balBefore + (atvlBalAfter - atvlBalBefore), poolBalBefore - poolBalAfter, "dfsgfg");

        assertEq(stakePool.poolBalance(), 0, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        assertTrue(
            nstblToken.balanceOf(address(stakePool)) >= 0 && nstblToken.balanceOf(address(stakePool)) - 1e24 <= 1e18,
            "check available tokens"
        );
    }

    function test_stake_unstake_burn_noYield_fuzz(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _investAmount,
        uint256 _burnAmount
    ) external {
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, 1e15 * 1e18);
        _amount2 = bound(_amount2, lowerBound, 1e15 * 1e18);
        _investAmount = bound(_investAmount, lowerBound * 2, 2 * 1e15 * 1e18);

        loanManager.updateInvestedAssets(_investAmount);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        assertEq(stakePool.getUserAvailableTokens(user1, 1), 0, "check available tokens");
        // Action
        _stakeNSTBL(user1, _amount1, 1);
        assertEq(stakePool.getUserAvailableTokens(user1, 1), _amount1, "check available tokens");

        // Post-condition
        assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        (uint256 amount, uint256 poolDebt,,) = stakePool.getStakerInfo(user1, 1);
        assertEq(amount, _amount1, "check stakerInfo.amount");
        assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

        _burnAmount = bound(_burnAmount, 0, stakePool.poolBalance());
        uint256 epochIdBefore = stakePool.poolEpochId();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        vm.startPrank(NSTBL_HUB);

        stakePool.burnNSTBL(_burnAmount);
        vm.stopPrank();

        if (poolBalanceBefore - _burnAmount <= 1e18) {
            assertEq(stakePool.poolBalance(), 0, "check poolBalance");
            assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
            assertEq(stakePool.poolEpochId() - epochIdBefore, 1, "check poolEpochId");
        }
        _stakeNSTBL(user2, _amount2, 2);

        vm.startPrank(NSTBL_HUB);

        uint256 balBefore = nstblToken.balanceOf(destinationAddress);
        stakePool.unstake(user1, 1, false, destinationAddress);
        uint256 balAfter = nstblToken.balanceOf(destinationAddress);

        if (poolBalanceBefore - _burnAmount <= 1e18) {
            //user 1 should receive 0 tokens
            assertEq(balAfter - balBefore, 0, "no tokens transferred");
        }
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        balBefore = balAfter;
        stakePool.unstake(user2, 2, false, destinationAddress);
        vm.stopPrank();
        balAfter = nstblToken.balanceOf(destinationAddress);
        // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        //user 2 should receive all his tokens
        assertEq(balAfter - balBefore + (nstblToken.balanceOf(atvl) - atvlBalBefore), _amount2, "no tokens transferred");

        //checking for pool empty state
        assertEq(stakePool.poolBalance(), 0, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

        assertTrue(
            nstblToken.balanceOf(address(stakePool)) >= 0 && nstblToken.balanceOf(address(stakePool)) <= 1e18,
            "check available tokens"
        );
    }
}
