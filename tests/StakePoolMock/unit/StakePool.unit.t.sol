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

    function test_proxy() external {
        assertEq(stakePool.aclManager(), address(aclManager));
        assertEq(stakePool.nstbl(), address(nstblToken));
        assertEq(stakePool.atvl(), address(atvl));
        assertEq(stakePool.loanManager(), address(loanManager));
        ERC20 lp = ERC20(address(stakePool.lpToken()));
        assertEq(lp.name(), "NSTBLStakePool LP Token");
        assertEq(lp.symbol(), "NSTBL_SP");
        assertEq(stakePool.poolProduct(), 1e18);
        assertEq(stakePool.getVersion(), 1);
        assertEq(uint256(vm.load(address(stakePool), bytes32(uint256(0)))), 1);

        vm.startPrank(deployer);
        NSTBLStakePool spImpl = new NSTBLStakePool();
        bytes memory data = abi.encodeCall(spImpl.initialize, (address(0), address(0), address(0), address(0)));
        vm.expectRevert("SP:INVALID_ADDRESS");
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(spImpl), address(proxyAdmin), data);
        data = abi.encodeCall(spImpl.initialize, (address(aclManager), address(nstblToken), address(loanManager), atvl));
        newProxy = new TransparentUpgradeableProxy(address(spImpl), address(proxyAdmin), data);

        NSTBLStakePool sp2 = NSTBLStakePool(address(newProxy));

        sp2.setupStakePool([300, 200, 100], [700, 500, 300], [30, 90, 180]);

        vm.stopPrank();
    }

    function test_setup_funcs() external {
        //action
        vm.prank(deployer);
        stakePool.setupStakePool([400, 300, 200], [900, 800, 700], [60, 120, 240]);

        //postcondition
        assertEq(stakePool.trancheBaseFee1(), 400, "check trancheFee1");
        assertEq(stakePool.trancheBaseFee2(), 300, "check trancheFee2");
        assertEq(stakePool.trancheBaseFee3(), 200, "check trancheFee3");
        assertEq(stakePool.earlyUnstakeFee1(), 900, "check earlyUnstakeFee1");
        assertEq(stakePool.earlyUnstakeFee2(), 800, "check earlyUnstakeFee2");
        assertEq(stakePool.earlyUnstakeFee3(), 700, "check earlyUnstakeFee3");
        assertEq(stakePool.trancheStakeTimePeriod(0), 60, "check trancheStakeTimePeriod1");
        assertEq(stakePool.trancheStakeTimePeriod(1), 120, "check trancheStakeTimePeriod2");
        assertEq(stakePool.trancheStakeTimePeriod(2), 240, "check trancheStakeTimePeriod3");
    }

    function test_genesisSetup() external {
        //action
        loanManager.updateInvestedAssets(1e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        //postcondition
        assertEq(stakePool.oldMaturityVal(), 1e6 * 1e18);

        //cannot reinitialize maturity value
        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: GENESIS");
        stakePool.updateMaturityValue();
        vm.stopPrank();
    }

    function test_setATVL() external {
        // Only the Admin can call
        vm.expectRevert();
        stakePool.setATVL(atvl);

        // Input address cannot be the zero address
        vm.prank(deployer);
        vm.expectRevert("SP:INVALID_ADDRESS");
        stakePool.setATVL(address(0));

        // setATVL works
        vm.prank(deployer);
        stakePool.setATVL(atvl);
        assertEq(stakePool.atvl(), atvl, "check atvl");
    }

    function test_stake_revert() external {
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(NSTBL_HUB, address(stakePool), 0);
        vm.expectRevert("SP: ZERO_AMOUNT"); // reverting due to zero amount
        stakePool.stake(user1, 0, 0, destinationAddress);
        vm.stopPrank();

        deal(address(nstblToken), NSTBL_HUB, 1e6 * 1e18);
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(NSTBL_HUB, address(stakePool), 1e6 * 1e18);
        vm.expectRevert("SP: INVALID_TRANCHE"); // reverting due to invalid trancheID
        stakePool.stake(user1, 1e6 * 1e18, 4, destinationAddress);
        vm.stopPrank();
    }

    //single staker, no yield
    //no restake
    function test_stake() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 1e6 * 1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 1e6 * 1e18);
        assertEq(_amount, 1e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6 * 1e18);
    }

    //single user, 1st staking event post 100 days of genesis state
    //all the accumulated yield before till the 1st stake is transferred to atvl
    function test_stake_case2() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 1e6 * 1e18, "check pool balance");
        assertEq(stakePool.poolProduct(), 1e18, "check pool product");
        assertEq(nstblToken.balanceOf(atvl), yield, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 1e6 * 1e18);
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 1e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6 * 1e18);
    }

    //single user, 1st staking event post 100 days of genesis state
    //mocking devaluation of t-bills
    function test_stake_case3() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        loanManager.updateInvestedAssets(8e6 * 1e18); //mocking t-bill devaluation just before time warp
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 1e6 * 1e18, "check pool balance");
        assertEq(stakePool.poolProduct(), 1e18, "check pool product");
        assertEq(nstblToken.balanceOf(atvl), 0, "check atvl balance"); //no yield due to t-bill devaluation
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 1e6 * 1e18);
        assertEq(stakePool.oldMaturityVal(), oldMaturityValue, "no update in maturity value");
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 1e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6 * 1e18);
    }

    //multiple stakers, no yield
    //no restake
    function test_stake_multipleTranches() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(20e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 2e6 * 1e18, 1);
        _stakeNSTBL(user3, 3e6 * 1e18, 2);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 7e6 * 1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 7e6 * 1e18);
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 1e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6 * 1e18);

        (_amount, _poolDebt,, _lpTokens,) = stakePool.getStakerInfo(user2, 0);
        assertEq(_amount, 1e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 1e6 * 1e18);

        (_amount, _poolDebt,, _lpTokens,) = stakePool.getStakerInfo(user2, 1);
        assertEq(_amount, 2e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 2e6 * 1e18);

        (_amount, _poolDebt,, _lpTokens,) = stakePool.getStakerInfo(user3, 2);
        assertEq(_amount, 3e6 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 3e6 * 1e18);
    }

    //single user, no yield
    //restaking in tranche 0, fee of 10% applied
    //fee is transferred to atvl
    function test_restake_case1() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 19e5 * 1e18);
        assertEq(nstblToken.balanceOf(atvl), 1e5 * 1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6 * 1e18);
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 19e5 * 1e18);
        assertEq(_poolDebt, 1e18);
        assertEq(_lpTokens, 2e6 * 1e18);
    }

    //single user, with yield, awaiting redemption active - no yield given to the pool
    //restaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_restake_case3() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        loanManager.updateAwaitingRedemption(true);
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(stakePool.poolBalance() - poolBalanceBefore, 197e4 * 1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), 3e4 * 1e18, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6 * 1e18, "check destination addr LP balance");
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, 197e4 * 1e18, "check user1 staked amount");
        assertEq(_poolDebt, 1e18, "check user1 pool debt");
        assertEq(_lpTokens, 2e6 * 1e18, "check user1 lp tokens");
    }

    //single user, with yield less than 1e18 => 0, awaiting redemption inactive
    //restaking in tranche 0 after 1 second, base fee of 10% applied
    //fee is transferred to atvl
    function test_restake_case4() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        vm.warp(block.timestamp + 1 seconds);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        assertEq(
            stakePool.poolBalance() - poolBalanceBefore, (1e6 * 1e18) * 90 / 100 + 1e6 * 1e18, "check pool balance"
        );
        assertEq(nstblToken.balanceOf(atvl), (1e6 * 1e18) * 10 / 100, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6 * 1e18, "check destination addr LP balance");
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, (1e6 * 1e18) * 90 / 100 + 1e6 * 1e18, "check user1 staked amount");
        assertEq(_poolDebt, stakePool.poolProduct(), "check user1 pool debt");
        assertEq(_lpTokens, 2e6 * 1e18, "check user1 lp tokens");
    }

    //single user, with yield, awaiting redemption inactive - yield given to the pool
    //all the yield is given to the pool since atvl balance is 0
    //restaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_restake_case5() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(
            stakePool.poolBalance() - poolBalanceBefore,
            (1e6 * 1e18 + yield) * 97 / 100 + 1e6 * 1e18,
            "check pool balance"
        );
        assertEq(nstblToken.balanceOf(atvl), (1e6 * 1e18 + yield) * 3 / 100, "check atvl balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 2e6 * 1e18, "check destination addr LP balance");
        (uint256 _amount, uint256 _poolDebt,, uint256 _lpTokens,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, (1e6 * 1e18 + yield) * 97 / 100 + 1e6 * 1e18, "check user1 staked amount");
        assertEq(_poolDebt, stakePool.poolProduct(), "check user1 pool debt");
        assertEq(_lpTokens, 2e6 * 1e18, "check user1 lp tokens");
    }

    //multiple stakers, with yield,  awaiting redemption inactive - yield given to the pool
    //all the yield is given to the pool since atvl balance is 0
    //restaking in all tranches
    //fee is transferred to atvl
    function test_restake_multipleTranches() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 poolBalanceBefore = stakePool.poolBalance();

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 1);
        _stakeNSTBL(user3, 1e6 * 1e18, 2);
        vm.warp(block.timestamp + 100 days);
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 1);
        _stakeNSTBL(user3, 1e6 * 1e18, 2);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(
            stakePool.poolBalance() - poolBalanceBefore + nstblToken.balanceOf(atvl),
            (6e6 * 1e18 + yield),
            "check pool balance and atvl balance"
        );
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress), 6e6 * 1e18, "check destination addr LP balance");
        (uint256 _amount,,,,) = stakePool.getStakerInfo(user1, 0);
        assertEq(_amount, (1e6 * 1e18 + yield / 3) * 97 / 100 + 1e6 * 1e18, "check user1 staked amount");

        (_amount,,,,) = stakePool.getStakerInfo(user2, 1);
        assertEq(_amount, (1e6 * 1e18 + yield / 3) * 98 / 100 + 1e6 * 1e18, "check user2 staked amount");

        (_amount,,,,) = stakePool.getStakerInfo(user3, 2);
        assertEq(_amount, (1e6 * 1e18 + yield / 3) * 9767 / 10_000 + 1e6 * 1e18, "check user3 staked amount");
    }

    function test_unstake_revert() external {
        vm.startPrank(NSTBL_HUB);
        vm.expectRevert("SP: NO STAKE");
        stakePool.unstake(user1, 0, false, destinationAddress);
        vm.stopPrank();

        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        deal(address(stakePool.lpToken()), destinationAddress, 1e3 * 1e18); //manipulating lp token balance

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
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);
        uint256 lpBalBefore = IERC20Helper(lp).balanceOf(destinationAddress);

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18);
        assertEq(nstblToken.balanceOf(atvl), 1e5 * 1e18);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 9e5 * 1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, no yield
    //instant unstake, maximum fee applied in all tranches
    function test_unstake_multipleTranches() external {
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        _stakeNSTBL(user2, 1e6 * 1e18, 1);
        _stakeNSTBL(user3, 1e6 * 1e18, 2);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user2, 1, false, destinationAddress)
        );
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user3, 2, false, destinationAddress)
        );

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 3e6 * 1e18);
        assertEq(nstblToken.balanceOf(atvl), 1e5 * 1e18 + 7e4 * 1e18 + 4e4 * 1e18);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 9e5 * 1e18 + 93e4 * 1e18 + 96e4 * 1e18);
    }

    //single staker, no yield
    //instant unstake, no fee applied because depeg is active
    function test_unstake_depeg() external {
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, true, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18);
        assertEq(nstblToken.balanceOf(atvl), 0);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 1e6 * 1e18);
    }

    //single staker, no yield
    //instant unstake, no tokens are transferred because poolEpochID is increased
    //mocking a burn event where all user tokens are burnt
    function test_unstake_case2() external {
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);
        uint256 poolBalanceBefore = stakePool.poolBalance();
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        vm.store(address(stakePool), bytes32(uint256(11)), bytes32(uint256(1))); //manually overriding the storage slot 11 (poolEpochID)
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, true, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 0);
        assertEq(nstblToken.balanceOf(atvl), 0);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 0);
    }

    //single staker, with yield, awaiting redemption active - no yield given to the pool
    //unstaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_unstake_case3() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18);
        assertEq(nstblToken.balanceOf(atvl), 3e4 * 1e18);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, 97e4 * 1e18);
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, with yield, awaiting redemption inactive - yield given to the pool
    //unstaking in tranche 0 after 100 days, base fee of 3% applied
    //fee is transferred to atvl
    function test_unstake_case4() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (1e6 * 1e18 + yield) * 3 / 100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (1e6 * 1e18 + yield) * 97 / 100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //revert due to burn amount greater than pool balance
    function test_burn_nstblTokens_revert() external {
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 5e5 * 1e18, "check pool balance");

        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl) - atvlBalBefore, (5e5 * 1e18) * 10 / 100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (5e5 * 1e18) * 90 / 100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, no yield
    //burning 100% tokens
    function test_burn_nstblTokens_case2() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18, "check pool balance");
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
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (5e5 * 1e18 + yield) * 3 / 100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (5e5 * 1e18 + yield) * 97 / 100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //single staker, with yield
    //burning 100% tokens, only yield gets transferred to the user
    //fee is transferred to atvl
    function test_burn_nstblTokens_case4() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
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
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );
        vm.stopPrank();

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(poolBalanceBefore - stakePool.poolBalance(), 1e6 * 1e18, "check pool balance");
        assertEq(nstblToken.balanceOf(atvl), (yield) * 3 / 100, "check atvl balance");
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (yield) * 97 / 100, "check hub balance");
        assertEq(IERC20Helper(lp).balanceOf(destinationAddress) - lpBalBefore, 0);
    }

    //@NOTE: updatePoolFromHub(....) is called only during redemption and deposit

    //mocking update during deposit with no pending redemption
    //no yield
    function test_updatePool_fromHub_case1() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        //action
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 5e5 * 1e18);

        //postcondition
        assertEq(stakePool.oldMaturityVal(), 35e5 * 1e18);
    }

    //mocking update during deposit with pending redemption
    //no yield
    function test_updatePool_fromHub_case2() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        loanManager.updateAwaitingRedemption(true); //manually setting pending redemption status
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        //action
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 5e5 * 1e18);

        //postcondition
        assertEq(stakePool.oldMaturityVal(), 35e5 * 1e18);
    }

    //mocking update during deposit with pending redemption
    //with yield, no yield is distributed due to pending redemption
    function test_updatePool_fromHub_case3() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        loanManager.updateAwaitingRedemption(true); //manually setting pending redemption status
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //action
        vm.warp(block.timestamp + 100 days);
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 5e5 * 1e18);

        //postcondition
        assertEq(stakePool.oldMaturityVal(), 35e5 * 1e18);
    }

    //mocking update during deposit with pending yield
    //pool - not empty
    function test_updatePool_fromHub_case4() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 oldMaturityValue = stakePool.oldMaturityVal();

        //action
        vm.warp(block.timestamp + 100 days);
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 5e5 * 1e18);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.oldMaturityVal(), 35e5 * 1e18 + yield);
        assertEq(stakePool.poolBalance(), 1e6 * 1e18 + yield);
        assertEq(nstblToken.balanceOf(atvl), 0);
    }

    //mocking update during deposit with pending yield
    //pool - empty
    function test_updatePool_fromHub_case5() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 nstblBalBefore = nstblToken.balanceOf(address(stakePool));

        //action
        vm.warp(block.timestamp + 100 days);
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 5e5 * 1e18);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.oldMaturityVal(), 35e5 * 1e18 + yield);
        assertEq(nstblToken.balanceOf(address(stakePool)) - nstblBalBefore, yield);
        assertEq(stakePool.unclaimedRewards(), yield);

        //withdrawing unclaimed rewards
        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        vm.prank(NSTBL_HUB);
        stakePool.withdrawUnclaimedRewards();

        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, yield);
    }

    //mocking update during deposit with t-bill devaluation
    //pool - empty
    function test_updatePool_fromHub_case6() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        uint256 oldMaturityValue = stakePool.oldMaturityVal();
        uint256 nstblBalBefore = nstblToken.balanceOf(address(stakePool));

        //action
        vm.warp(block.timestamp + 100 days);
        loanManager.updateInvestedAssets(2e6 * 1e18); //mocking t-bill devaluation
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(false, 0, 5e5 * 1e18);

        //postcondition
        assertEq(stakePool.oldMaturityVal(), 35e5 * 1e18);
        assertEq(nstblToken.balanceOf(address(stakePool)) - nstblBalBefore, 0);
    }

    //mocking update during redemption
    //with yield, pool not empty
    //unstaking for user as well
    function test_updatePool_fromHub_case7() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        uint256 hubBalBefore = nstblToken.balanceOf(NSTBL_HUB);

        //action
        loanManager.updateInvestedAssets(25e5 * 1e18);
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(NSTBL_HUB);
        stakePool.updatePoolFromHub(true, 5e5 * 1e18, 0);
        nstblToken.sendOrReturnPool(
            address(stakePool), NSTBL_HUB, stakePool.unstake(user1, 0, false, destinationAddress)
        );

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - 25e5 * 1e18;
        assertEq(stakePool.oldMaturityVal(), 25e5 * 1e18 + yield);
        assertEq(stakePool.poolBalance(), 0);
        assertEq(nstblToken.balanceOf(NSTBL_HUB) - hubBalBefore, (1e6 * 1e18 + yield) * 97 / 100);
        assertEq(nstblToken.balanceOf(atvl), (1e6 * 1e18 + yield) * 3 / 100);
    }

    //mocking update during redemption and t-bill devaluation
    //with yield, pool not empty
    function test_updatePool_fromHub_case8() external {
        //precondition
        loanManager.updateInvestedAssets(3e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        //action
        loanManager.updateInvestedAssets(22e5 * 1e18); //mocking t-bill devalution
        vm.warp(block.timestamp + 100 days);
        vm.prank(NSTBL_HUB);
        stakePool.updatePoolFromHub(true, 5e5 * 1e18, 0);

        //postcondition
        assertEq(stakePool.oldMaturityVal(), 3e6 * 1e18);
        assertEq(stakePool.poolBalance(), 1e6 * 1e18);
    }

    function test_preview_userTokens() external {
        address lp = address(stakePool.lpToken());
        //precondition
        loanManager.updateInvestedAssets(10e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        uint256 oldMaturityValue = stakePool.oldMaturityVal();

        assertEq(stakePool.getUserAvailableTokens(user1, 0), 0);

        //action
        _stakeNSTBL(user1, 1e6 * 1e18, 0);

        assertEq(stakePool.getUserAvailableTokens(user1, 0), 1e6 * 1e18);

        vm.warp(block.timestamp + 100 days);

        //postcondition
        uint256 yield = loanManager.getMaturedAssets() - oldMaturityValue;
        assertEq(stakePool.getUserAvailableTokens(user1, 0), 1e6 * 1e18 + yield);
    }

    //empty pool with yield
    function test_review_updatePool() external {
        //precondition
        loanManager.updateInvestedAssets(1e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();

        vm.warp(block.timestamp + 10 days);
        assertEq(stakePool.previewUpdatePool(), 0);
    }

    //non-empty pool with 0 yield
    function test_review_updatePool_case2() external {
        //precondition
        loanManager.updateInvestedAssets(1e6 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
        _stakeNSTBL(user1, 1e3 * 1e18, 0);

        vm.warp(block.timestamp + 10 seconds);
        assertEq(stakePool.previewUpdatePool(), 0);
    }
}
