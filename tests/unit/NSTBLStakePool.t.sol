// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../helpers/Setup.t.sol";

contract StakePoolTest is BaseTest {
    using SafeERC20 for IERC20Helper;

    function setUp() public override{
        super.setUp();
    }

    function test_contractDeployment() external {

        assertEq(stakePool.lUSDC(), address(loanManager.lUSDC()));
        assertEq(stakePool.lUSDT(), address(loanManager.lUSDT()));
        assertEq(nstblToken.balanceOf(admin), 1e6*1e18);
        assertEq(nstblToken.totalSupply(), 1e6*1e18);
        assertEq(IERC20Helper(stakePool.lUSDC()).balanceOf(admin), 1e6*1e18);
        assertEq(IERC20Helper(stakePool.lUSDT()).balanceOf(admin), 1e6*1e18);
    }

    function test_Stake() external {

    }
}