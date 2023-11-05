// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Test, console } from "forge-std/Test.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { NSTBLStakePool } from "../../../contracts/StakePool.sol";
// import { ACLManager } from "@nstbl-acl-manager/contracts/ACLManager.sol";
import { LoanManagerMock } from "../../../contracts/mocks/LoanManagerMock.sol";
import { NSTBLToken } from "@nstbl-token/contracts/NSTBLToken.sol";
import { testToken } from "@nstbl-token/tests/Token.t.sol";
import { ChainlinkPriceFeed } from "../../../contracts/chainlink/ChainlinkPriceFeed.sol";
import { IERC20Helper } from "../../../contracts/interfaces/IERC20Helper.sol";

contract BaseTest is testToken {
    using SafeERC20 for IERC20Helper;

    NSTBLStakePool public stakePool;
    // ACLManager public aclManager;
    ChainlinkPriceFeed public priceFeed;
    LoanManagerMock public loanManager;
    NSTBLToken public nstblToken;

    address public atvl = address(4);

    address usdc = address(34_536_543);

    function setUp() public virtual override{
        super.setUp();
        // uint256 mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/CFhLkcCEs1dFGgg0n7wu3idxcdcJEgbW");
        // vm.selectFork(mainnetFork);
        vm.startPrank(owner);

        // aclManager = new ACLManager();
        aclManager.setAuthorizedCallerStakePool(NSTBL_HUB, true);

        priceFeed = new ChainlinkPriceFeed();
        loanManager = new LoanManagerMock(owner);
        nstblToken = localOFTToken;
        stakePool = new NSTBLStakePool(
            address(aclManager),
            address(nstblToken),
            address(loanManager)
            );
        aclManager.setAuthorizedCallerToken(address(stakePool), true);
        nstblToken.setStakePoolAddress(address(stakePool));
        stakePool.init(atvl, 900, 4000);
        stakePool.configurePool(250, 30, 5000);
        stakePool.configurePool(350, 60, 3000);
        stakePool.configurePool(400, 90, 1000);
        loanManager.initializeTime();
        vm.stopPrank();
    }

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        console.log("Balance of account: ", IERC20Helper(asset_).balanceOf(account_));
        IERC20Helper(asset_).safeTransfer(destination_, amount_);
        vm.stopPrank();
    }

    function _stakeNstbl(uint256 _amount, uint256 _poolId, address _user) internal {
        // erc20_transfer(address(nstblToken), owner, NSTBL_HUB, _amount);
        deal(address(nstblToken), NSTBL_HUB, _amount);
        console.log("Balance of NSTBL_HUB: ", IERC20Helper(address(nstblToken)).balanceOf(NSTBL_HUB));
        vm.startPrank(NSTBL_HUB);
        IERC20Helper(address(nstblToken)).safeIncreaseAllowance(address(stakePool), _amount);
        stakePool.stake(_amount, _user, _poolId);
        vm.stopPrank();
    }
}
