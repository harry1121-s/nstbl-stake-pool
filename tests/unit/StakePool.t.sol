// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../helpers/BaseTest.t.sol";

contract StakePoolTest is BaseTest {
    using SafeERC20 for IERC20Helper;

    function setUp() public override {
        super.setUp();
    }

    function test_contractDeployment() external {
        assertEq(nstblToken.balanceOf(admin), 1e8 * 1e18);
        assertEq(nstblToken.totalSupply(), 1e8 * 1e18);
    }

    function test_stake() external {
        _stakeNstbl(1e6 * 1e18, 0, user1);

        assertEq(stakePool.totalStakedAmount(), 1e6 * 1e18);
        assertEq(stakePool.getUserStakedAmount(user1, 0), 1e6 * 1e18);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);
    }

    function test_unstake_singlePool() external {

        _stakeNstbl(1e6 * 1e18, 0, user1);

        loanManager.updateInvestedAssets(15e5 * 1e18);

        vm.warp(block.timestamp + 12 days);
        
        assertEq(stakePool.getUserStakedAmount(user1, 0), 1e6 * 1e18);
        assertEq(stakePool.getUserRewardDebt(user1, 0), 0);
        uint256 nstblBalBefore = nstblToken.balanceOf(nealthyAddr);
        vm.startPrank(nealthyAddr);

        stakePool.unstake(1e6 * 1e18, user1, 0);
        uint256 nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
        vm.stopPrank();

        assertEq(stakePool.getUserStakedAmount(user1, 0), 0);

    }

    function test_unstake_MultiplePools() external {

        _stakeNstbl(1e6 * 1e18, 0, user1);
        _stakeNstbl(1e6 * 1e18, 0, user2);
        _stakeNstbl(1e6 * 1e18, 1, user2);
        _stakeNstbl(1e6 * 1e18, 2, user3);

        loanManager.updateInvestedAssets(10e6 * 1e18);

        assertEq(nstblToken.balanceOf(address(stakePool)), 4e6 * 1e18);
        assertEq(stakePool.totalStakedAmount(), 4e6 * 1e18);
        vm.warp(block.timestamp + 30 days);

        uint256 nstblBalBefore = nstblToken.balanceOf(nealthyAddr);
        vm.startPrank(nealthyAddr);
        stakePool.unstake(1e6 * 1e18, user1, 0);
        uint256 nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
        vm.stopPrank();

        console.log("NSTBLs received: %s", nstblBalAfter - nstblBalBefore);

        nstblBalBefore = nstblToken.balanceOf(nealthyAddr);
        vm.startPrank(nealthyAddr);
        stakePool.unstake(1e6 * 1e18, user2, 0);
        nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
        vm.stopPrank();

        console.log("NSTBLs received: %s", nstblBalAfter - nstblBalBefore);

        uint256 atvlBal1 = nstblToken.balanceOf(atvl);
        uint256 atvYield = stakePool.atvlExtraYield();
        stakePool.transferATVLYield(0);
        uint256 atvlBal2 = nstblToken.balanceOf(atvl);
        assertEq(atvYield, atvlBal2 - atvlBal1);

         vm.startPrank(nealthyAddr);
        stakePool.unstake(1e6 * 1e18, user2, 1);
        nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
        vm.stopPrank();

         vm.startPrank(nealthyAddr);
        stakePool.unstake(1e6 * 1e18, user3, 2);
        nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
        vm.stopPrank();

        // assertEq(nstblToken.balanceOf(address(stakePool)), 0);       

    }
}
