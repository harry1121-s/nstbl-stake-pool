// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../helpers/BaseTest.t.sol";

contract StakePoolTest is BaseTest {
    using SafeERC20 for IERC20Helper;

    function setUp() public override {
        super.setUp();
    }

    // function test_contractDeployment() external {
    //     assertEq(nstblToken.balanceOf(admin), 1e8 * 1e18);
    //     assertEq(nstblToken.totalSupply(), 1e8 * 1e18);
    // }

    // function test_stake() external {
    //     _stakeNstbl(1e6 * 1e18, 0, user1);

    //     assertEq(stakePool.totalStakedAmount(), 1e6 * 1e18);
    //     assertEq(stakePool.getUserStakedAmount(user1, 0), 1e6 * 1e18);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);
    // }

    // function test_unstake_singlePool() external {

    //     _stakeNstbl(1e6 * 1e18, 0, user1);

    //     loanManager.updateInvestedAssets(15e5 * 1e18);

    //     vm.warp(block.timestamp + 12 days);
        
    //     assertEq(stakePool.getUserStakedAmount(user1, 0), 1e6 * 1e18);
    //     assertEq(stakePool.getUserRewardDebt(user1, 0), 0);
    //     uint256 nstblBalBefore = nstblToken.balanceOf(nealthyAddr);
    //     vm.startPrank(nealthyAddr);

    //     stakePool.unstake(1e6 * 1e18, user1, 0);
    //     uint256 nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
    //     vm.stopPrank();

    //     assertEq(stakePool.getUserStakedAmount(user1, 0), 0);

    // }

    // function test_unstake_MultiplePools() external {

    //     _stakeNstbl(1e6 * 1e18, 0, user1);
    //     _stakeNstbl(1e6 * 1e18, 0, user2);
    //     _stakeNstbl(1e6 * 1e18, 1, user2);
    //     _stakeNstbl(1e6 * 1e18, 2, user3);

    //     loanManager.updateInvestedAssets(10e6 * 1e18);
    //     vm.warp(block.timestamp + 300 days);



    //     assertEq(nstblToken.balanceOf(address(stakePool)), 4e6 * 1e18);
    //     assertEq(stakePool.totalStakedAmount(), 4e6 * 1e18);

    //     stakePool.updatePools();

    //     // uint256 nstblBalBefore = nstblToken.balanceOf(nealthyAddr);
    //     // vm.startPrank(nealthyAddr);
    //     // stakePool.unstake(1e6 * 1e18, user1, 0);
    //     // uint256 nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
    //     // vm.stopPrank();

    //     // console.log("NSTBLs received: %s", nstblBalAfter - nstblBalBefore);

    //     // nstblBalBefore = nstblToken.balanceOf(nealthyAddr);
    //     // vm.startPrank(nealthyAddr);
    //     // stakePool.unstake(1e6 * 1e18, user2, 0);
    //     // nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
    //     // vm.stopPrank();

    //     // console.log("NSTBLs received: %s", nstblBalAfter - nstblBalBefore);

    //     // uint256 atvlBal1 = nstblToken.balanceOf(atvl);
    //     // uint256 atvYield = stakePool.atvlExtraYield();
    //     // stakePool.transferATVLYield(0);
    //     // uint256 atvlBal2 = nstblToken.balanceOf(atvl);
    //     // assertEq(atvYield, atvlBal2 - atvlBal1);

    //     //  vm.startPrank(nealthyAddr);
    //     // stakePool.unstake(1e6 * 1e18, user2, 1);
    //     // nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
    //     // vm.stopPrank();

    //     //  vm.startPrank(nealthyAddr);
    //     // stakePool.unstake(1e6 * 1e18, user3, 2);
    //     // nstblBalAfter = nstblToken.balanceOf(nealthyAddr);
    //     // vm.stopPrank();
    //     // console.log("Remaining NSTBL balance of StakePool", nstblToken.balanceOf(address(stakePool)));
    //     // console.log("NSTBL balance of ATVL", nstblToken.balanceOf(atvl));
    //     // console.log("ATVL StakeAmount: ", stakePool.getUserStakedAmount(atvl, 0));
    //     // console.log("ATVL Yield: ", stakePool.atvlExtraYield());

    //     // assertEq(nstblToken.balanceOf(address(stakePool)), 0);       

    // }

    function test_updateYieldParams_case1() external {
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
