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

    // function test_proxy() external {
    //     assertEq(stakePool.aclManager(), address(aclManager));
    //     assertEq(stakePool.nstbl(), address(nstblToken));
    //     assertEq(stakePool.atvl(), address(atvl));
    //     assertEq(stakePool.loanManager(), address(loanManager));
    //     ERC20 lp = ERC20(address(stakePool.lpToken()));
    //     assertEq(lp.name(), "NSTBLStakePool LP Token");
    //     assertEq(lp.symbol(), "NSTBL_SP");
    //     assertEq(stakePool.poolProduct(), 1e18);
    //     assertEq(stakePool.getVersion(), 1);
    //     assertEq(uint256(vm.load(address(stakePool), bytes32(uint256(0)))), 1);

    //     vm.startPrank(deployer);
    //     NSTBLStakePool spImpl = new NSTBLStakePool();
    //      bytes memory data = abi.encodeCall(
    //         spImpl.initialize, (address(0), address(0), address(0), address(0))
    //     );
    //     vm.expectRevert("SP:INVALID_ADDRESS");
    //     TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(spImpl), address(proxyAdmin), data);
    //      data = abi.encodeCall(
    //         spImpl.initialize, (address(aclManager), address(nstblToken), address(loanManager), atvl)
    //     );
    //     newProxy = new TransparentUpgradeableProxy(address(spImpl), address(proxyAdmin), data);

    //     NSTBLStakePool sp2 = NSTBLStakePool(address(newProxy));

    //     sp2.setupStakePool([300, 200, 100], [700, 500, 300], [30, 90, 180]);

    //     vm.stopPrank();
    // }
  
    // function test_setup_funcs() external {
    //     vm.startPrank(deployer);
    //     stakePool.setupStakePool([400, 300, 200], [900, 800, 700], [60, 120, 240]);
    //     vm.stopPrank();
    //     // assertEq(stakePool.yieldThreshold(), 500_388_127, "check yieldThreshold");
    //     assertEq(stakePool.trancheBaseFee1(), 400, "check trancheFee1");
    //     assertEq(stakePool.trancheBaseFee2(), 300, "check trancheFee2");
    //     assertEq(stakePool.trancheBaseFee3(), 200, "check trancheFee3");
    //     assertEq(stakePool.earlyUnstakeFee1(), 900, "check earlyUnstakeFee1");
    //     assertEq(stakePool.earlyUnstakeFee2(), 800, "check earlyUnstakeFee2");
    //     assertEq(stakePool.earlyUnstakeFee3(), 700, "check earlyUnstakeFee3");
    //     assertEq(stakePool.trancheStakeTimePeriod(0), 60, "check trancheStakeTimePeriod1");
    //     assertEq(stakePool.trancheStakeTimePeriod(1), 120, "check trancheStakeTimePeriod2");
    //     assertEq(stakePool.trancheStakeTimePeriod(2), 240, "check trancheStakeTimePeriod3");
    //     vm.prank(deployer);
    //     stakePool.setATVL(vm.addr(987));
    //     assertEq(stakePool.atvl(), vm.addr(987), "check atvl");
    // }

    // function test_setATVL() external {
    //     // Only the Admin can call
    //     vm.expectRevert();
    //     stakePool.setATVL(atvl);

    //     // Input address cannot be the zero address
    //     vm.prank(deployer);
    //     vm.expectRevert();
    //     stakePool.setATVL(address(0));

    //     // setATVL works
    //     vm.prank(deployer);
    //     stakePool.setATVL(atvl);
    //     assertEq(stakePool.atvl(), atvl, "check atvl");
    // }

    // function test_updatePoolFromHub() external {
    //     uint256 _amount = 10_000_000 * 1e18;
    //     uint8 _trancheId = 0;

    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.prank(NSTBL_HUB);
    //     stakePool.updateMaturityValue();
    //     uint256 maturityVal = stakePool.oldMaturityVal();
    //     vm.warp(block.timestamp + 12 days);
    //     vm.startPrank(NSTBL_HUB);
    //     stakePool.updatePoolFromHub(false, 0, 0);
    //     uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     stakePool.withdrawUnclaimedRewards();
    //     vm.stopPrank();
    //     uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     assertEq(loanManager.getMaturedAssets() - 15e5 * 1e18, hubBalAfter - hubBalBefore, "No rewards to withdraw");

    //     assertEq(stakePool.poolBalance(), 0);

    //     // Action
    //     _stakeNSTBL(user1, _amount, _trancheId);
    //     vm.warp(block.timestamp + 12 days);
    //     loanManager.updateAwaitingRedemption(true);

    //     // Mocking for updatePoolFromHub during deposit when awaiting redemption is active
    //     vm.startPrank(NSTBL_HUB);
    //     uint256 oldVal = stakePool.oldMaturityVal();
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), true, "Awaiting Redemption status");
    //     stakePool.updatePoolFromHub(false, 0, 1e6 * 1e18);
    //     assertEq(stakePool.oldMaturityVal(), oldVal + 1e6 * 1e18, "No update due to awaiting redemption");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during deposit when awaiting redemption is inactive
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateInvestedAssets(15e5 * 1e18 + 1e6 * 1e18);
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(false);
    //     assertEq(loanManager.getAwaitingRedemptionStatus(usdc), false, "Awaiting Redemption status");
    //     stakePool.updatePoolFromHub(false, 0, 1e6 * 1e18);
    //     uint256 newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal - maturityVal, loanManager.getMaturedAssets() - 15e5 * 1e18 + 1e6 * 1e18, "UpdateRewards");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active
    //     loanManager.updateInvestedAssets(15e5 * 1e18 + 2e6 * 1e18); //because deposit was made 2 times previosuly
    //     vm.warp(block.timestamp + 12 days);
    //     vm.startPrank(NSTBL_HUB);
    //     oldVal = stakePool.oldMaturityVal();
    //     loanManager.updateAwaitingRedemption(true);
    //     stakePool.updatePoolFromHub(true, 1e3 * 1e18, 0);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal - oldVal, loanManager.getMaturedAssets() - oldVal, "Reward update due to redemption");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during Maple redemption when awaiting redemption is active and tBills are devalued
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateInvestedAssets(15e5 * 1e18);
    //     vm.warp(block.timestamp + 12 days);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePoolFromHub(true, 1e3 * 1e18, 0);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal, "No reward update due to ,aple devalue");
    //     vm.stopPrank();

    //     // Mocking for updatePoolFromHub during deposit when tBills are devalued
    //     vm.startPrank(NSTBL_HUB);
    //     loanManager.updateAwaitingRedemption(false);
    //     vm.warp(block.timestamp + 12 days);
    //     oldVal = stakePool.oldMaturityVal();
    //     stakePool.updatePoolFromHub(false, 0, 1e6 * 1e18);
    //     newVal = stakePool.oldMaturityVal();
    //     assertEq(newVal, oldVal + 1e6 * 1e18, "No reward update due to Maple devalue");
    //     vm.stopPrank();
    // }

    // function test_stake_fuzz(uint256 _amount1, uint256 _amount2, uint256 _amount3, uint256 _investAmount, uint256 _time)
    //     external
    // {
    //     uint256 lowerBound = 1 * 1e18;
    //     _amount1 = bound(_amount1, lowerBound, 1e19 * 1e18);
    //     _amount2 = bound(_amount2, lowerBound, 1e19 * 1e18);
    //     _amount3 = bound(_amount3, lowerBound, 1e19 * 1e18);
    //     _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e21 * 1e18);
    //     _time = bound(_time, 10 days, 5 * 365 days); // randomize for all three don't use same time
    //     // fuzz awaiting redemption
    //     // write stateless fuzz

    //     loanManager.updateInvestedAssets(_investAmount);
    //     vm.prank(NSTBL_HUB);
    //     stakePool.updateMaturityValue();

    //     _stakeNSTBL(user1, _amount1, 0);
    //     _stakeNSTBL(user2, _amount2, 1);
    //     _stakeNSTBL(user3, _amount3, 2);
    //     address lp = address(stakePool.lpToken());
    //     assertEq(IERC20Helper(lp).balanceOf(destinationAddress), _amount1 + _amount2 + _amount3, "check LP balance");
    //     assertEq(stakePool.poolBalance(), _amount1 + _amount2 + _amount3, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

    //     vm.warp(block.timestamp + _time);
    //     uint256 tokensUser1 = stakePool.getUserAvailableTokens(user1, 0);
    //     uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
    //     _stakeNSTBL(user1, _amount1, 0);
    //     assertApproxEqRel(stakePool.getUserAvailableTokens(user1, 0), (tokensUser1 + _amount1), 1e17, "check user1 available tokens");
    //     uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
    //         assertApproxEqAbs(
    //             poolBalAfter - poolBalBefore + (atvlBalAfter - atvlBalBefore),
    //             _amount1 + (loanManager.getMaturedAssets() - _investAmount),
    //             1e18,
    //             "with yield"
    //         );
    //     } else {
    //         assertEq(poolBalAfter - poolBalBefore + (atvlBalAfter - atvlBalBefore), _amount1, "without yield");
    //     }
    // }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test_stake_revert() external {

        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(NSTBL_HUB, address(stakePool), 0);
        vm.expectRevert("SP: ZERO_AMOUNT"); // reverting due to zero amount
        stakePool.stake(user1, 0, 0, destinationAddress);
        vm.stopPrank();

        deal(address(nstblToken), NSTBL_HUB, 1e6*1e18);
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(NSTBL_HUB, address(stakePool), 1e6*1e18);
        vm.expectRevert("SP: INVALID_TRANCHE"); // reverting due to invalid trancheID
        stakePool.stake(user1, 1e6*1e18, 4, destinationAddress);
        vm.stopPrank();

    }

    //single staker, no yield
    //no restake
    function test_stake() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 1e6*1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 1e6*1e18);
        assertEq(_amount, 1e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6*1e18);

    }

    //single user, 1st staking event post 100 days of genesis state
    //all the accumulated yield before till the 1st stake is transferred to atvl
    function test_stake_case2() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 1e6*1e18, "check pool balance");
        assertEq(stakePool.poolProduct(), 1e18, "check pool product");
        assertEq(nstblToken.balanceOf(atvl), yield, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 1e6*1e18);
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 1e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6*1e18);

    }


    //single user, 1st staking event post 100 days of genesis state
    //mocking devaluation of t-bills
    function test_stake_case3() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        loanManager.updateInvestedAssets(8e6*1e18); //mocking t-bill devaluation just before time warp
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 1e6*1e18, "check pool balance");
        assertEq(stakePool.poolProduct(), 1e18, "check pool product");
        assertEq(nstblToken.balanceOf(atvl), 0, "check atvl balance"); //no yield due to t-bill devaluation
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 1e6*1e18);
        assertEq(stakePool.oldMaturityVal(), oldMaturityValue, "no update in maturity value");
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 1e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6*1e18);

    }

    //multiple stakers, no yield
    //no restake
    function test_stake_multipleTranches() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(20e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 2e6 * 1e18, 1);
        _stakeNSTBL(user3, 3e6 * 1e18, 2);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 7e6*1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 7e6*1e18);
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 1e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6*1e18);

        (_amount, _poolDebt, , _lpTokens, ) = stakePool.getStakerInfo(user2, 0);
        assertEq(_amount, 1e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6*1e18);

        (_amount, _poolDebt, , _lpTokens, ) = stakePool.getStakerInfo(user2, 1);
        assertEq(_amount, 2e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 2e6*1e18);

        (_amount, _poolDebt, , _lpTokens, ) = stakePool.getStakerInfo(user3, 2);
        assertEq(_amount, 3e6*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 3e6*1e18);

    }

    //single user, no yield
    //restaking in tranche 0, fee of 10% applied 
    //fee is transferred to atvl
    function test_restake_case1() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 19e5*1e18);
        assertEq(nstblToken.balanceOf(atvl), 1e5*1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6*1e18);
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 19e5*1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 2e6*1e18);

    }

    //single user, with yield, awaiting redemption active - no yield given to the pool
    //restaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_restake_case3() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        loanManager.updateAwaitingRedemption(true);
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        vm.warp(block.timestamp + 100 days);
        console.log("RESTAKING-------------------------");
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 197e4*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), 3e4*1e18, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6*1e18, "check destination addr LP balance");
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 197e4*1e18, "check user1 staked amount");
        assertEq(_poolDebt, 1e18, "check user1 pool debt");
        assertEq(_lpTokens, 2e6*1e18, "check user1 lp tokens");
    }

    //single user, with yield less than 1e18 => 0, awaiting redemption inactive 
    //restaking in tranche 0 after 1 second, base fee of 10% applied
    //fee is transferred to atvl
    function test_restake_case4() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18); 
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        vm.warp(block.timestamp + 1 seconds);
        console.log("RESTAKING-------------------------");
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, (1e6*1e18)*90/100 + 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (1e6*1e18)*10/100, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6*1e18, "check destination addr LP balance");
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, (1e6*1e18)*90/100 + 1e6*1e18, "check user1 staked amount");
        assertEq(_poolDebt, stakePool.poolProduct(), "check user1 pool debt");
        assertEq(_lpTokens, 2e6*1e18, "check user1 lp tokens");
    }

    //single user, with yield, awaiting redemption inactive - yield given to the pool
    //all the yield is given to the pool since atvl balance is 0
    //restaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_restake_case5() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        vm.warp(block.timestamp + 100 days);
        console.log("RESTAKING-------------------------");
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.poolBalance() - poolBalanceBefore, (1e6*1e18 + yield)*97/100 + 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (1e6*1e18 + yield)*3/100, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6*1e18, "check destination addr LP balance");
        (uint256 _amount, uint256 _poolDebt, , uint256 _lpTokens, ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, (1e6*1e18 + yield)*97/100 + 1e6*1e18, "check user1 staked amount");
        assertEq(_poolDebt, stakePool.poolProduct(), "check user1 pool debt");
        assertEq(_lpTokens, 2e6*1e18, "check user1 lp tokens");
    }
    
    //multiple stakers, with yield,  awaiting redemption inactive - yield given to the pool
    //all the yield is given to the pool since atvl balance is 0
    //restaking in all tranches
    //fee is transferred to atvl
    function test_restake_multipleTranches() external{

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 1);
        _stakeNSTBL(user3, 1e6 * 1e18, 2);
        vm.warp(block.timestamp + 100 days);
        console.log("RESTAKING-------------------------");
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 1);
        _stakeNSTBL(user3, 1e6 * 1e18, 2);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.poolBalance() - poolBalanceBefore + nstblToken.balanceOf(atvl), (6e6*1e18 + yield), "check pool balance and atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 6e6*1e18, "check destination addr LP balance");
        (uint256 _amount, , , , ) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, (1e6*1e18 + yield/3)*97/100 + 1e6*1e18, "check user1 staked amount");

        ( _amount, , , , ) = stakePool.getStakerInfo(user2, 1);
        assertEq(_amount, (1e6*1e18 + yield/3)*98/100 + 1e6*1e18, "check user2 staked amount");

        ( _amount, , , , ) = stakePool.getStakerInfo(user3, 2);
        assertEq(_amount, (1e6*1e18 + yield/3)*9767/10000 + 1e6*1e18, "check user3 staked amount");
        
    }


    function test_unstake_revert() external {

        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: NO STAKE");
        stakePool.unstake(user1, 0, false, destinationAddress);
        vm.stopPrank();

        _stakeNSTBL(user1, 1e6*1e18, 0);
        deal(address(stakePool.lpToken()), destinationAddress, 1e3*1e18); //manipulating lp token balance 

        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: Insuff LP Balance");
        stakePool.unstake(user1, 0, false, destinationAddress);
        vm.stopPrank();
    }

    //single staker, no yield
    //instant unstake, fee of 10% applied in tranche 0
    function test_unstake() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18);
        assertEq(nstblToken.balanceOf(atvl), 1e5*1e18);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 9e5*1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);

    }

    //single staker, no yield
    //instant unstake, maximum fee applied in all tranches
    function test_unstake_multipleTranches() external {

         //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 1);
        _stakeNSTBL(user3, 1e6 * 1e18, 2);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user2, 1, false, destinationAddress));
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user3, 2, false, destinationAddress));

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 3e6*1e18);
        assertEq(nstblToken.balanceOf(atvl), 1e5*1e18 + 7e4*1e18 + 4e4*1e18);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 9e5*1e18 + 93e4*1e18 + 96e4*1e18);
    }

    //single staker, no yield
    //instant unstake, no fee applied because depeg is active
    function test_unstake_depeg() external {

        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, true, destinationAddress));
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18);
        assertEq(nstblToken.balanceOf(atvl), 0);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 1e6*1e18);

    }

    //single staker, no yield
    //instant unstake, no tokens are transferred because poolEpochID is increased
    //mocking a burn event where all user tokens are burnt
    function test_unstake_case2() external {

        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        vm.store(address(stakePool), bytes32(uint256(11)), bytes32(uint256(1))); //manually overriding the storage slot 11 (poolEpochID)
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, true, destinationAddress));
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 0);
        assertEq(nstblToken.balanceOf(atvl), 0);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 0);

    }

    //single staker, with yield, awaiting redemption active - no yield given to the pool
    //unstaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_unstake_case3() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        loanManager.updateAwaitingRedemption(true);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);


        //action
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18);
        assertEq(nstblToken.balanceOf(atvl), 3e4*1e18);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 97e4*1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
        
    }

    //single staker, with yield, awaiting redemption inactive - yield given to the pool
    //unstaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_unstake_case4() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);


        //action
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (1e6*1e18 + yield) * 3/100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (1e6*1e18 + yield)*97/100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
        
    }

    //revert due to burn amount greater than pool balance
    function test_burn_nstblTokens_revert() external {

        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);


        //action
        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: Burn > SP_BALANCE");
        stakePool.burnNSTBL(11e5 * 1e18);
        vm.stopPrank();

       
    }

    //single staker, no yield
    //burning 50% tokens
    //fee is transferred to atvl
    function test_burn_nstblTokens() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);


        //action
        vm.startPrank(NSTBL_HUB);
        stakePool.burnNSTBL(5e5 * 1e18); //burnt 50% tokens
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 5e5*1e18, "check pool balance");

        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl) - atvlBalBefore, (5e5*1e18) * 10/100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (5e5*1e18)*90/100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, no yield
    //burning 100% tokens
    function test_burn_nstblTokens_case2() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);


        //action
        vm.startPrank(NSTBL_HUB);
        stakePool.burnNSTBL(1e6 * 1e18); //burnt 50% tokens
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl) - atvlBalBefore, 0, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 0, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, with yield
    //burning 50% tokens
    //fee is transferred to atvl
    function test_burn_nstblTokens_case3() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);


        //action
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(NSTBL_HUB);
        stakePool.burnNSTBL(5e5 * 1e18); //burnt 50% tokens
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (5e5*1e18 + yield) * 3/100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (5e5*1e18 + yield) * 97/100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, with yield
    //burning 100% tokens, only yield gets transferred to the user
    //fee is transferred to atvl
    function test_burn_nstblTokens_case4() external {

        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6*1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);


        //action
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(NSTBL_HUB);
        stakePool.burnNSTBL(1e6 * 1e18); //burnt 50% tokens
        nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress));
        vm.stopPrank();

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(poolBalanceBefore - stakePool.poolBalance() , 1e6*1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (yield) * 3/100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (yield) * 97/100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

   
    



    // function test_unstake_fuzz(uint256 _amount1, uint256 _amount2, uint256 _investAmount, uint256 _time) external {
    //     uint256 lowerBound = 10 * 1e18;
    //     _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
    //     _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
    //     _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
    //     _time = bound(_time, 0, 5 * 365 days);

    //     loanManager.updateInvestedAssets(_investAmount);
    //     vm.prank(NSTBL_HUB);
    //     stakePool.updateMaturityValue();

    //     _stakeNSTBL(user1, _amount1, 0);
    //     _stakeNSTBL(user2, _amount2, 1);
    //     address lp = address(stakePool.lpToken());
    //     assertEq(IERC20Helper(lp).balanceOf(destinationAddress), _amount1 + _amount2, "check LP balance");

    //     vm.warp(block.timestamp + _time);

    //     vm.startPrank(NSTBL_HUB);
    //     uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 atvlBalBefore = nstblToken.balanceOf(atvl);

    //     nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress) + stakePool.unstake(user2, 1, true, destinationAddress));

    //     uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 atvlBalAfter = nstblToken.balanceOf(atvl);

    //     (,,, uint256 stakerLP1,) = stakePool.getStakerInfo(user1, 0);
    //     (,,, uint256 stakerLP2,) = stakePool.getStakerInfo(user2, 1);
    //     // if (_time / 1 days <= stakePool.trancheStakeTimePeriod(0) + 1) {
    //     if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
    //         assertApproxEqAbs(
    //             hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore),
    //             _amount2 + _amount1 + (loanManager.getMaturedAssets() - _investAmount),
    //             1e18,
    //             "with yield"
    //         );
    //     } else {
    //         assertEq(hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore), _amount1 + _amount2, "without yield");
    //     }
    //     assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 0, "check LP balance");
    //     assertEq(stakerLP1, 0);
    //     // } else {
    //     //     assertEq(IERC20Helper(lp).balanceOf(destinationAddress), _amount1, "check LP balance");
    //     // }
    //     assertEq(stakerLP2, 0);
    //     assertEq(stakePool.poolBalance(), 0);
    //     vm.startPrank(NSTBL_HUB);
    //     vm.expectRevert("SP: NO STAKE");
    //     nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user3, 0, false, destinationAddress));
    //     vm.stopPrank();
    //     vm.warp(block.timestamp + 100 days);
    //     assertEq(stakePool.previewUpdatePool(), 0);
    //     _stakeNSTBL(user4, 1e3*1e18, 1);
    // }

    // function test_stake_unstake_updatePool_fuzz(
    //     uint256 _amount1,
    //     uint256 _amount2,
    //     uint256 _investAmount,
    //     uint256 _time
    // ) external {
    //     uint256 lowerBound = 10 * 1e18;
    //     _amount1 = bound(_amount1, lowerBound, 1e12 * 1e18);
    //     _amount2 = bound(_amount2, lowerBound, 1e12 * 1e18);
    //     _investAmount = bound(_investAmount, 7 * (_amount1 + _amount2) / 8, 1e15 * 1e18);
    //     // _investAmount = bound(_investAmount, 1e24, 1e15 * 1e18);
    //     _time = bound(_time, 0, 5 * 365 days);

    //     loanManager.updateInvestedAssets(_investAmount);
    //     vm.startPrank(NSTBL_HUB);
    //     stakePool.updateMaturityValue();

    //     vm.expectRevert("SP: GENESIS");
    //     stakePool.updateMaturityValue();
    //     vm.stopPrank();
    //     // Action
    //     deal(address(nstblToken), address(stakePool), 1e24); // just to mess with the system
    //     _stakeNSTBL(user1, _amount1, 1);

    //     // Should revert if the amount is zero
    //     vm.startPrank(NSTBL_HUB);
    //     vm.expectRevert("SP: ZERO_AMOUNT");
    //     stakePool.stake(user1, 0, 1, destinationAddress);
    //     vm.stopPrank();

        
    //     // Should revert if trancheId is invalid
    //     vm.startPrank(NSTBL_HUB);
    //     vm.expectRevert("SP: INVALID_TRANCHE");
    //     stakePool.stake(user1, 1e3*1e18, 3, destinationAddress);
    //     vm.stopPrank();


    //     // Post-condition
    //     assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
    //     (uint256 amount, uint256 poolDebt,,,) = stakePool.getStakerInfo(user1, 1);
    //     assertEq(amount, _amount1, "check stakerInfo.amount");
    //     assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

    //     vm.warp(block.timestamp + _time);
    //     // Action
    //     _stakeNSTBL(user2, _amount2, 2);

    //     // Post-condition
    //     if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
    //         assertEq(
    //             stakePool.poolBalance(),
    //             _amount1 + _amount2 + (loanManager.getMaturedAssets() - _investAmount),
    //             "check poolBalance1"
    //         );
    //     } else {
    //         assertEq(stakePool.poolBalance(), _amount1 + _amount2, "check poolBalance3");
    //     }

    //     (amount, poolDebt,,,) = stakePool.getStakerInfo(user2, 2);
    //     assertEq(amount, _amount2, "check stakerInfo.amount");

    //     uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalBefore = nstblToken.balanceOf(address(stakePool));
    //     uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
     
    //     vm.startPrank(NSTBL_HUB);
    //     hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

    //     nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 1, false, destinationAddress));

    //     uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 atvlBalAfter = nstblToken.balanceOf(atvl);

    //     // Post-condition; stakeAmount + all yield transferred
    //     // if (_time / 1 days <= stakePool.trancheStakeTimePeriod(1) + 1) {
    //     if ((loanManager.getMaturedAssets() - _investAmount) > 1e18) {
    //         assertApproxEqAbs(
    //             hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore),
    //             _amount1 + (loanManager.getMaturedAssets() - _investAmount),
    //             1e18
    //         );
    //     } else {
    //         assertEq(hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore), _amount1);
    //     }

    //     nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user2, 2, false, destinationAddress));
    //     vm.stopPrank();
    //     atvlBalAfter = nstblToken.balanceOf(atvl);
    //     hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     uint256 poolBalAfter = nstblToken.balanceOf(address(stakePool));

    //     assertEq(hubBalAfter - hubBalBefore + (atvlBalAfter - atvlBalBefore), poolBalBefore - poolBalAfter, "dfsgfg");

    //     stakePool.transferATVLYield();
    //     assertEq(stakePool.atvlExtraYield(), 0, "check atvlExtraYield");
    //     assertEq(stakePool.poolBalance(), 0, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
    //     assertTrue(
    //         nstblToken.balanceOf(address(stakePool)) >= 0 && nstblToken.balanceOf(address(stakePool)) - 1e24 <= 1e18,
    //         "check available tokens"
    //     );
       
    // }
    // function test_burnNSTBL_revert() external {

    //     loanManager.updateInvestedAssets(1e6*1e18);
    //     vm.prank(NSTBL_HUB);
    //     stakePool.updateMaturityValue();

    //     assertEq(stakePool.getUserAvailableTokens(user1, 1), 0, "check available tokens");
    //     // Action
    //     _stakeNSTBL(user1, 1e5 * 1e18, 1);
    //     assertEq(stakePool.getUserAvailableTokens(user1, 1), 1e5*1e18, "check available tokens");
        
    //     vm.startPrank(NSTBL_HUB);
    //     vm.expectRevert();
    //     stakePool.burnNSTBL(1e6*1e18);

    // }
    // function test_stake_unstake_burn_noYield_fuzz(
    //     uint256 _amount1,
    //     uint256 _amount2,
    //     uint256 _investAmount,
    //     uint256 _burnAmount
    // ) external {
    //     uint256 lowerBound = 10 * 1e18;
    //     _amount1 = bound(_amount1, lowerBound, 1e15 * 1e18);
    //     _amount2 = bound(_amount2, lowerBound, 1e15 * 1e18);
    //     _investAmount = bound(_investAmount, lowerBound * 2, 2 * 1e15 * 1e18);

    //     loanManager.updateInvestedAssets(_investAmount);
    //     vm.prank(NSTBL_HUB);
    //     stakePool.updateMaturityValue();

    //     assertEq(stakePool.getUserAvailableTokens(user1, 1), 0, "check available tokens");
    //     // Action
    //     _stakeNSTBL(user1, _amount1, 1);
    //     assertEq(stakePool.getUserAvailableTokens(user1, 1), _amount1, "check available tokens");

    //     // Post-condition
    //     assertEq(stakePool.poolBalance(), _amount1, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
    //     (uint256 amount, uint256 poolDebt,,,) = stakePool.getStakerInfo(user1, 1);
    //     assertEq(amount, _amount1, "check stakerInfo.amount");
    //     assertEq(poolDebt, 1e18, "check stakerInfo.poolDebt");

    //     _burnAmount = bound(_burnAmount, 0, stakePool.poolBalance());
    //     uint256 epochIdBefore = stakePool.poolEpochId();
    //     uint256 poolBalanceBefore = stakePool.poolBalance();
        
    //     vm.startPrank(NSTBL_HUB);

    //     stakePool.burnNSTBL(_burnAmount);
    //     vm.stopPrank();

    //     if (poolBalanceBefore - _burnAmount <= 1e18) {
    //         assertEq(stakePool.poolBalance(), 0, "check poolBalance");
    //         assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");
    //         assertEq(stakePool.poolEpochId() - epochIdBefore, 1, "check poolEpochId");
    //     }
    //     _stakeNSTBL(user2, _amount2, 2);

    //     uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     vm.startPrank(NSTBL_HUB);

    //     hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
    //     nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 1, false, destinationAddress));
    //     uint256 hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);

    //     if (poolBalanceBefore - _burnAmount <= 1e18) {
    //         //user 1 should receive 0 tokens
    //         assertEq(hubBalAfter - hubBalBefore, 0, "no tokens transferred");
    //     }
    //     uint256 atvlBalBefore = nstblToken.balanceOf(atvl);
    //     hubBalBefore = hubBalAfter;
    //     nstblToken.sendOrReturnPool(address(stakePool), NSTBL_HUB, stakePool.unstake(user2, 2, false, destinationAddress));
    //     vm.stopPrank();
    //     hubBalAfter = nstblToken.balanceOf(NSTBL_HUB);
    //     // uint256 atvlBalAfter = nstblToken.balanceOf(atvl);
    //     //user 2 should receive all his tokens
    //     assertEq(
    //         hubBalAfter - hubBalBefore + (nstblToken.balanceOf(atvl) - atvlBalBefore), _amount2, "no tokens transferred"
    //     );

    //     //checking for pool empty state
    //     assertEq(stakePool.atvlExtraYield(), 0, "check atvlExtraYield");
    //     assertEq(stakePool.poolBalance(), 0, "check poolBalance");
    //     assertEq(stakePool.poolProduct(), 1e18, "check poolProduct");

    //     assertTrue(
    //         nstblToken.balanceOf(address(stakePool)) >= 0 && nstblToken.balanceOf(address(stakePool)) <= 1e18,
    //         "check available tokens"
    //     );
    // }
}
