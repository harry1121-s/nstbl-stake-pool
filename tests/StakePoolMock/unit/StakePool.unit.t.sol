// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseTest.t.sol";
import "../../../contracts/IStakePool.sol";

contract StakePoolTest is BaseTest {
    using SafeERC20 for IERC20Helper;

    /*//////////////////////////////////////////////////////////////
    Setup
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public override {
        super.setUp();
    }

    function test_proxy() external{
        
        assertEq(stakePool.aclManager(), address(aclManager));
        assertEq(stakePool.nstbl(), address(nstblToken));
        assertEq(stakePool.atvl(), address(atvl));
        assertEq(stakePool.loanManager(), address(loanManager));
        ERC20 lp = ERC20(address(stakePool.lpToken()));
        assertEq(lp.name(), "NSTBLStakePool LP Token");
        assertEq(lp.symbol(), "NSTBL_SP");
        assertEq(stakePool.poolProduct(), 1e18);
        assertEq(stakePool.yieldThreshold(), 285_388_127);
        assertEq(stakePool.getVersion(), 1);
        assertEq(uint256(vm.load(address(stakePool), bytes32(uint256(0)))), 1);

    }
    // function test_deployment() external {
    //     // Check deployment
    //     assertEq(stakePool.aclManager(), address(aclManager), "check aclManager");
    //     assertEq(stakePool.nstbl(), address(nstblToken), "check nstblToken");
    //     assertEq(stakePool.atvl(), address(atvl), "check atvl");

    //     // Test failing Deployment

    //     // ACLManager cannot be the zero address
    //     vm.expectRevert("SP:INVALID_ADDRESS");
    //     NSTBLStakePool stakePoolTemp = new NSTBLStakePool(
    //         address(0),
    //         address(nstblToken),
    //         address(loanManager),
    //         atvl
    //     );

    //     // nSTBL token cannot be the zero address
    //     vm.expectRevert("SP:INVALID_ADDRESS");
    //     stakePoolTemp = new NSTBLStakePool(
    //         address(aclManager),
    //         address(0),
    //         address(loanManager),
    //         atvl
    //     );

    //     // loanManager cannot be the zero address
    //     vm.expectRevert("SP:INVALID_ADDRESS");
    //     stakePoolTemp = new NSTBLStakePool(
    //         address(aclManager),
    //         address(nstblToken),
    //         address(0),
    //         atvl
    //     );

    //     // ATVL cannot be the zero address
    //     vm.expectRevert("SP:INVALID_ADDRESS");
    //     stakePoolTemp = new NSTBLStakePool(
    //         address(aclManager),
    //         address(nstblToken),
    //         address(loanManager),
    //         address(0)
    //     );
    // }

    function test_init_funcs() external {
        vm.startPrank(deployer);
        stakePool.init(atvl, 500_388_127, [400, 300, 200], [900, 800, 700], [60, 120, 240]);
        vm.stopPrank();
        assertEq(stakePool.atvl(), atvl, "check atvl");
        assertEq(stakePool.yieldThreshold(), 500_388_127, "check yieldThreshold");
        assertEq(stakePool.trancheBaseFee1(), 400, "check trancheFee1");
        assertEq(stakePool.trancheBaseFee2(), 300, "check trancheFee2");
        assertEq(stakePool.trancheBaseFee3(), 200, "check trancheFee3");
        assertEq(stakePool.earlyUnstakeFee1(), 900, "check earlyUnstakeFee1");
        assertEq(stakePool.earlyUnstakeFee2(), 800, "check earlyUnstakeFee2");
        assertEq(stakePool.earlyUnstakeFee3(), 700, "check earlyUnstakeFee3");
        assertEq(stakePool.trancheStakeTimePeriod(0), 60, "check trancheStakeTimePeriod1");
        assertEq(stakePool.trancheStakeTimePeriod(1), 120, "check trancheStakeTimePeriod2");
        assertEq(stakePool.trancheStakeTimePeriod(2), 240, "check trancheStakeTimePeriod3");
        vm.prank(deployer);
        stakePool.setATVL(vm.addr(987));
        assertEq(stakePool.atvl(), vm.addr(987), "check atvl");
    }

    function test_setATVL() external {
        // Only the Admin can call
        vm.expectRevert();
        stakePool.setATVL(atvl);

        // Input address cannot be the zero address
        vm.prank(deployer);
        vm.expectRevert();
        stakePool.setATVL(address(0));

        // setATVL works
        vm.prank(deployer);
        stakePool.setATVL(atvl);
        assertEq(stakePool.atvl(), atvl, "check atvl");
    }

    function test_updatePool() external {
        uint256 _amount = 10_000_000 * 1e18;
        uint8 _trancheId = 0;

        loanManager.updateInvestedAssets(15e5 * 1e18);
        stakePool.updateMaturyValue();
        console.log("Maturity Value: ", stakePool.oldMaturityVal());

        uint256 maturityVal = stakePool.oldMaturityVal();
        vm.warp(block.timestamp + 12 days);
        stakePool.updatePool();
        assertEq(stakePool.poolBalance(), 0);

        // Action
        _stakeNSTBL(user1, _amount, _trancheId);
        vm.warp(block.timestamp + 12 days);
        loanManager.updateAwaitingRedemption(usdc, true);

        // Mocking for updatePool when awaiting redemption is active
        uint256 oldVal = stakePool.oldMaturityVal();
        assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
        stakePool.updatePool();
        assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption");
        assertEq(stakePool.poolProduct(), 1e18, "No update due to awaiting redemption");
        assertEq(stakePool.poolBalance(), 10_000_000 * 1e18, "No update due to awaiting redemption");

        // Mocking for updatePool when awaiting redemption is inactive
        oldVal = stakePool.oldMaturityVal();
        loanManager.updateAwaitingRedemption(usdc, false);
        assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
        stakePool.updatePool();
        uint256 newVal = stakePool.oldMaturityVal();
        assertEq(newVal - maturityVal, loanManager.getMaturedAssets(usdc) - 15e5 * 1e18, "UpdateRewards");

        // Mocking for updatePool when tBills are devalued
        loanManager.updateInvestedAssets(10e5 * 1e18);
        vm.warp(block.timestamp + 12 days);
        oldVal = stakePool.oldMaturityVal();
        stakePool.updatePool();
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal, oldVal, "No reward update due to Maple devalue");
    }

    function test_updatePoolFromHub() external {
        uint256 _amount = 10_000_000 * 1e18;
        uint8 _trancheId = 0;

        loanManager.updateInvestedAssets(15e5 * 1e18);
        stakePool.updateMaturyValue();
        uint256 maturityVal = stakePool.oldMaturityVal();
        vm.warp(block.timestamp + 12 days);
        vm.startPrank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 0);
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        stakePool.withdrawUnclaimedRewards();
        vm.stopPrank();
        uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        assertEq(loanManager.getMaturedAssets(usdc) - 15e5 * 1e18, hubBalAfter - hubBalBefore, "No rewards to withdraw");

        assertEq(stakePool.poolBalance(), 0);

        // Action
        _stakeNSTBL(user1, _amount, _trancheId);
        vm.warp(block.timestamp + 12 days);
        loanManager.updateAwaitingRedemption(usdc, true);

        // Mocking for updatePoolFromHub during deposit when awaiting redemption is active
        vm.startPrank(NSTBL_HUB);
        uint256 oldVal = stakePool.oldMaturityVal();
        assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
        stakePool.updatePoolFromHub(false, 0, 1e6 * 1e18);
        assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during deposit when awaiting redemption is inactive
        vm.startPrank(NSTBL_HUB);
        oldVal = stakePool.oldMaturityVal();
        loanManager.updateAwaitingRedemption(usdc, false);
        assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
        stakePool.updatePoolFromHub(false, 0, 1e6 * 1e18);
        uint256 newVal = stakePool.oldMaturityVal();
        assertEq(newVal - maturityVal, loanManager.getMaturedAssets(usdc) - 15e5 * 1e18 + 1e6 * 1e18, "UpdateRewards");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active
        loanManager.updateInvestedAssets(15e5 * 1e18 + 1e6 * 1e18);
        vm.warp(block.timestamp + 12 days);
        vm.startPrank(NSTBL_HUB);
        oldVal = stakePool.oldMaturityVal();
        loanManager.updateAwaitingRedemption(usdc, true);
        stakePool.updatePoolFromHub(true, 1e3 * 1e18, 0);
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal - oldVal, loanManager.getMaturedAssets(usdc) - oldVal, "Reward update due to redemption");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active and tBills are devalued
        vm.startPrank(NSTBL_HUB);
        loanManager.updateInvestedAssets(15e5 * 1e18);
        vm.warp(block.timestamp + 12 days);
        oldVal = stakePool.oldMaturityVal();
        stakePool.updatePoolFromHub(true, 1e3 * 1e18, 0);
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal, oldVal, "No reward update due to ,aple devalue");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during deposit when tBills are devalued
        vm.startPrank(NSTBL_HUB);
        loanManager.updateAwaitingRedemption(usdc, false);
        vm.warp(block.timestamp + 12 days);
        oldVal = stakePool.oldMaturityVal();
        stakePool.updatePoolFromHub(false, 0, 1e6 * 1e18);
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal, oldVal, "No reward update due to Maple devalue");
        vm.stopPrank();
    }

    function test_updatePoolFromHub_fuzz(uint256 _amount, uint256 _time) external {
        _amount = bound(_amount, 1e19, 1e15 * 1e18);
        _time = bound(_time, 0, 100 days);
        uint8 _trancheId = uint8(_amount % 3);

        // Action
        _stakeNSTBL(user1, _amount, _trancheId);
        loanManager.updateInvestedAssets(_amount * 4);
        stakePool.updateMaturyValue();
        vm.warp(block.timestamp + _time);
        loanManager.updateAwaitingRedemption(usdc, true);

        // Mocking for updatePoolFromHub during deposit when awaiting redemption is active
        vm.startPrank(NSTBL_HUB);
        uint256 oldVal = stakePool.oldMaturityVal();
        assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
        stakePool.updatePoolFromHub(false, 0, _amount / 10);
        assertEq(stakePool.oldMaturityVal(), oldVal, "No update due to awaiting redemption");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during deposit when awaiting redemption is inactive
        vm.startPrank(NSTBL_HUB);
        oldVal = stakePool.oldMaturityVal();
        loanManager.updateAwaitingRedemption(usdc, false);
        assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
        stakePool.updatePoolFromHub(false, 0, _amount / 10);
        uint256 newVal = stakePool.oldMaturityVal();
        assertEq(newVal - oldVal, loanManager.getMaturedAssets(usdc) - _amount * 4 + _amount / 10, "UpdateRewards");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active
        loanManager.updateInvestedAssets(_amount * 4 + _amount / 10);
        vm.warp(block.timestamp + _time);
        vm.startPrank(NSTBL_HUB);
        oldVal = stakePool.oldMaturityVal();
        loanManager.updateAwaitingRedemption(usdc, true);
        stakePool.updatePoolFromHub(true, _amount / 100, 0);
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal - oldVal, loanManager.getMaturedAssets(usdc) - oldVal, "Reward update due to redemption");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active and tBills are devalued
        vm.startPrank(NSTBL_HUB);
        loanManager.updateInvestedAssets(_amount * 4);
        vm.warp(block.timestamp + _time);
        oldVal = stakePool.oldMaturityVal();
        stakePool.updatePoolFromHub(true, _amount / 100, 0);
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal, oldVal, "No reward update due to ,aple devalue");
        vm.stopPrank();

        // Mocking for updatePoolFromHub during deposit when tBills are devalued
        vm.startPrank(NSTBL_HUB);
        loanManager.updateAwaitingRedemption(usdc, true);
        vm.warp(block.timestamp + _time);
        oldVal = stakePool.oldMaturityVal();
        stakePool.updatePoolFromHub(false, 0, _amount / 10);
        newVal = stakePool.oldMaturityVal();
        assertEq(newVal, oldVal, "No reward update due to Maple devalue");
        vm.stopPrank();
    }

    function test_stake_fuzz(uint256 _amount1, uint256 _amount2, uint256 _amount3, uint256 _investAmount, uint256 _time)
        external
    {
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
        _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
        _amount3 = bound(_amount3, lowerBound, 1e12 * 1e18);
        _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
        _time = bound(_time, 0, 5 * 365 days);

        loanManager.updateInvestedAssets(_investAmount);
        stakePool.updateMaturyValue();

        _stakeNSTBL(user1, _amount1, 0);
        _stakeNSTBL(user2, _amount2, 1);
        _stakeNSTBL(user3, _amount3, 2);
        address lp = address(stakePool.lpToken());
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), _amount1 + _amount2 + _amount3, "check LP balance");
        assertEq(stakePool.poolBalance(), _amount1 + _amount2 + _amount3, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

        vm.warp(block.timestamp + _time);

        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        _stakeNSTBL(user1, _amount1, 0);
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        if ((loanManager.getMaturedAssets(usdc) - _investAmount) > 1e18) {
            assertApproxEqAbs(
                poolBalAfter - poolBalBefore + (atvlBalAfter - atvlBalBefore),
                _amount1 + (loanManager.getMaturedAssets(usdc) - _investAmount),
                1e18,
                "with yield"
            );
        } else {
            console.log("assertion params", poolBalAfter - poolBalBefore, atvlBalAfter - atvlBalBefore, _amount1);
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
        stakePool.updateMaturyValue();

        _stakeNSTBL(user1, _amount1, 0);
        _stakeNSTBL(user2, _amount2, 1);
        address lp = address(stakePool.lpToken());
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), _amount1 + _amount2, "check LP balance");

        vm.warp(block.timestamp + _time);

        vm.startPrank(NSTBL_HUB);
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        stakePool.unstake(user1, 0, false, destinationAddress);
        stakePool.unstake(user2, 1, true, destinationAddress);
        uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);

        (,,, uint256 stakerLP1) = stakePool.getStakerInfo(user1, 0);
        (,,, uint256 stakerLP2) = stakePool.getStakerInfo(user2, 1);
        if (_time / 1 days <= stakePool.trancheStakeTimePeriod(0) + 1) {
            if ((loanManager.getMaturedAssets(usdc) - _investAmount) > 1e18) {
                assertApproxEqAbs(
                    hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore),
                    _amount2 + _amount1 + (loanManager.getMaturedAssets(usdc) - _investAmount),
                    1e18,
                    "with yield"
                );
            } else {
                assertEq(
                    hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore), _amount1 + _amount2, "without yield"
                );
            }
            assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 0, "check LP balance");
            assertEq(stakerLP1, 0);
        } else {
            assertEq(IERC20Helper(lp).balanceOf(destinationAddress), _amount1, "check LP balance");
        }
        assertEq(stakerLP2, 0);

        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: NO STAKE");
        stakePool.unstake(user3, 0, false, destinationAddress);
        vm.stopPrank();
    }

    function test_stake_unstake_updatePool_fuzz(uint256 _amount1, uint256 _amount2, uint256 _investAmount, uint256 _time)
        external
    {
        uint256 lowerBound = 10 * 1e18;
        _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
        _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
        _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
        // _investAmount = bound(_investAmount, 1e24, 1e15 * 1e18);
        _time = bound(_time, 0, 5 * 365 days);

        loanManager.updateInvestedAssets(_investAmount);
        stakePool.updateMaturyValue();
        // Action
        deal(address(nstblToken), address(stakePool), 1e24); // just to mess with the system
        _stakeNSTBL(user1, _amount1, 1);

        // Post-condition
        assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        (uint256 amount, uint256 poolDebt,,) = stakePool.getStakerInfo(user1, 1);
        assertEq(amount, _amount1, "check stakerInfo.amount");
        assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

        vm.warp(block.timestamp + _time);
        console.log("----------------------------staking after time warp--------------------------");
        // Action
        _stakeNSTBL(user2, _amount2, 2);

        // Post-condition
        if ((loanManager.getMaturedAssets(usdc) - _investAmount) > 1e18) {
            assertEq(
                stakePool.poolBalance(),
                _amount1 + _amount2 + (loanManager.getMaturedAssets(usdc) - _investAmount),
                "check poolBalance1"
            );
        } else {
            assertEq(stakePool.poolBalance(), _amount1 + _amount2, "check poolBalance3");
        }

        (amount, poolDebt,,) = stakePool.getStakerInfo(user2, 2);
        assertEq(amount, _amount2, "check stakerInfo.amount");

        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        console.log("  ----------------------------- unstaking alllll ]-------------------------");
        vm.startPrank(NSTBL_HUB);
        hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        stakePool.unstake(user1, 1, false, destinationAddress);
        uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        uint256 atvlBalAfter = nstblToken.balanceOf(atvl);

        // Post-condition; stakeAmount + all yield transferred
        if (_time / 1 days <= stakePool.trancheStakeTimePeriod(1) + 1) {
            if ((loanManager.getMaturedAssets(usdc) - _investAmount) > 1e18) {
                assertApproxEqAbs(
                    hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore),
                    _amount1 + (loanManager.getMaturedAssets(usdc) - _investAmount),
                    1e18
                );
            } else {
                assertEq(hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore), _amount1);
            }
        } else {
            assertEq(hubBalAfter - hubBalBefore, 0);
        }

        stakePool.unstake(user2, 2, false, destinationAddress);
        vm.stopPrank();
        atvlBalAfter = nstblToken.balanceOf(atvl);
        hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));

        assertEq(hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore), poolBalBefore - poolBalAfter, "dfsgfg");
        console.log(poolBalAfter, stakePool.atvlExtraYield(), "checking");

        stakePool.transferATVLYield();
        assertEq(stakePool.atvlExtraYield(), 0, "check atvlExtraYield");
        if (_time / 1 days <= stakePool.trancheStakeTimePeriod(1) + 1) {
            assertEq(stakePool.poolBalance(), 0, "check poolBalance");
            assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
            assertTrue(
                nstblToken.balanceOf(address(stakePool)) >= 0 && nstblToken.balanceOf(address(stakePool)) - 1e24 <= 1e18,
                "check available tokens"
            );
        } else {
            if ((loanManager.getMaturedAssets(usdc) - _investAmount) > 1e18) {
                assertApproxEqAbs(
                    stakePool.poolBalance(), _amount1 + (loanManager.getMaturedAssets(usdc) - _investAmount), 1e18
                );
            } else {
                assertEq(stakePool.poolBalance(), _amount1);
            }
        }
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
        stakePool.updateMaturyValue();

        // Action
        _stakeNSTBL(user1, _amount1, 1);

        // Post-condition
        assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
        (uint256 amount, uint256 poolDebt,,) = stakePool.getStakerInfo(user1, 1);
        assertEq(amount, _amount1, "check stakerInfo.amount");
        assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

        _burnAmount = bound(_burnAmount, 0, stakePool.poolBalance());
        uint256 epochIdBefore = stakePool.poolEpochId();
        uint256 poolBalanceBefore = stakePool.poolBalance();
        vm.prank(NSTBL_HUB);
        stakePool.burnNSTBL(_burnAmount);

        if (poolBalanceBefore - _burnAmount <= 1e18) {
            assertEq(stakePool.poolBalance(), 0, "check poolBalance");
            assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
            assertEq(stakePool.poolEpochId() - epochIdBefore, 1, "check poolEpochId");
        }
        _stakeNSTBL(user2, _amount2, 2);

        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        console.log("  ----------------------------- unstaking alllll ]-------------------------");
        vm.startPrank(NSTBL_HUB);
        hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        stakePool.unstake(user1, 1, false, destinationAddress);
        uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);

        if (poolBalanceBefore - _burnAmount <= 1e18) {
            //user 1 should receive 0 tokens
            assertEq(hubBalAfter - hubBalBefore, 0, "no tokens transferred");
        }
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        hubBalBefore = hubBalAfter;
        stakePool.unstake(user2, 2, false, destinationAddress);
        vm.stopPrank();
        hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
        // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
        //user 2 should receive all his tokens
        assertEq(
            hubBalAfter - hubBalBefore + (nstblToken.balanceOf(atvl) - atvlBalBefore), _amount2, "no tokens transferred"
        );

        //checking for pool empty state
        assertEq(stakePool.atvlExtraYield(), 0, "check atvlExtraYield");
        assertEq(stakePool.poolBalance(), 0, "check poolBalance");
        assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

        assertTrue(
            nstblToken.balanceOf(address(stakePool)) >= 0 && nstblToken.balanceOf(address(stakePool)) <= 1e18,
            "check available tokens"
        );
    }
}
