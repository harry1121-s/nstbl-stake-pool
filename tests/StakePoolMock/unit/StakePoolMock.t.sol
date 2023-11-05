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
    function test_stake_singleUser() external {
        uint256 _amount = 100_00_000 * 1e18;
        bytes11 _stakeId = bytes11(0x1122334455667788991122);
        uint8 _trancheId = 0;

        // Action
        vm.store(address(stakePool), bytes32(uint256(3)), bytes32(uint256(3)));
        vm.store(address(stakePool), bytes32(uint256(4)), bytes32(uint256(3)));
        _stakeNSTBL(_amount, _stakeId, _trancheId);

        // Post-condition
        uint256 rewardDebt = (_amount * stakePool.accNSTBLPerShare()) / 1e18;
        _checkStakePostCondition(_stakeId, _trancheId, NSTBL_HUB, _amount, rewardDebt, rewardDebt, block.timestamp);
        assertEq(stakePool.totalStakedAmount(), _amount, "check totalStakedAmount");
    }

    function test_stake_singleUser_fuzz(uint256 _amount, bytes11 _stakeId, uint8 _trancheId, uint256 _share) external {
        // Pre-condition
        _amount = bound(_amount, 1, type(uint256).max / 1e32);
        _share = bound(_share, 1, 1e32);
        _trancheId = uint8(bound(_trancheId, 0, 3));

        // Action
        vm.store(address(stakePool), bytes32(uint256(3)), bytes32(uint256(_share)));
        vm.store(address(stakePool), bytes32(uint256(4)), bytes32(uint256(_share)));
        _stakeNSTBL(_amount, _stakeId, _trancheId);

        // Post-condition
        uint256 rewardDebt = (_amount * stakePool.accNSTBLPerShare()) / 1e18;
        _checkStakePostCondition(_stakeId, _trancheId, NSTBL_HUB, _amount, rewardDebt, rewardDebt, block.timestamp);
        assertEq(stakePool.totalStakedAmount(), _amount, "check totalStakedAmount");
    }

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

    function test_stake_multipleUsers_fuzz(uint256 _amount, bytes11 _stakeId, uint256 _share) external {
        // Pre-condition
        _amount = bound(_amount, 1, type(uint256).max / 1e32);
        _share = bound(_share, 1e18, 5e18);
        uint256 upperBound = 5;

        bytes11[] memory stakeIds = new bytes11[](upperBound);
        uint[] memory index = new uint[](upperBound);
        for(uint256 i = 0; i < upperBound; i++) {
            (_stakeId, index[i]) = _randomizeStakeIdAndIndex(_stakeId, upperBound);
            stakeIds[i] = _stakeId;
        }

        for(uint256 i = 0; i < upperBound; i++) {
            (,,,
            uint256 amount,
            uint256 rewardDebt,
            uint256 burnDebt,
            ) = stakePool.stakerInfo(stakeIds[index[i]]);
            _share *= 2;

            // Action
            vm.store(address(stakePool), bytes32(uint256(3)), bytes32(uint256(_share)));
            _stakeNSTBL(_amount, stakeIds[index[i]], uint8(_amount % 3));
            
            uint256 debt = (_amount * _share) / 1e18;

            if(amount == 0) {
                // Check Condition
                _checkStakePostCondition(stakeIds[index[i]], uint8(_amount % 3), NSTBL_HUB, _amount, debt, 0, block.timestamp);
            }
            else {
                // Check Condition
                debt = burnDebt + (amount * _share / 1e18);
                debt = amount + debt - (amount *  stakePool.burnNSTBLPerShare()/ 1e18 + rewardDebt);
                debt += _amount;
                uint256 debt2 = (debt * stakePool.accNSTBLPerShare()) / 1e18;
                _checkStakePostCondition(stakeIds[index[i]], uint8(_amount % 3), NSTBL_HUB, debt, debt2, 0, block.timestamp);
            }
            
        }
    }

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
