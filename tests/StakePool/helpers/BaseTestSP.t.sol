// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {console } from "forge-std/Test.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { NSTBLStakePool } from "../../../contracts/StakePool.sol";
import { TokenLP } from "../../../contracts/TokenLP.sol";
import { LoanManager } from "@loanManager/contracts/LoanManager.sol";
import { BaseTest} from "@loanManager/tests/helpers/BaseTest.t.sol";
import { NSTBLVaultMock } from "../../../contracts/mocks/NSTBLVaultMock.sol";
import { NSTBLTokenMock } from "../../../contracts/mocks/NSTBLTokenMock.sol";
import { ChainlinkPriceFeed } from "../../../contracts/chainlink/ChainlinkPriceFeed.sol";
import { IERC20Helper } from "../../../contracts/interfaces/IERC20Helper.sol";
import { ATVL } from "../../../contracts/atvl/ATVL.sol";

contract BaseTestSP is BaseTest {
    using SafeERC20 for IERC20Helper;

    NSTBLStakePool public stakePool;
    ChainlinkPriceFeed public priceFeed;
    TokenLP public lpToken;
    // LoanManager public loanManager;
    NSTBLVaultMock public nstblVault;
    NSTBLTokenMock public nstblToken;
    ATVL public Atvl;

    // address public admin = address(123);
    address public nealthyAddr = address(456);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public atvl;

    // address usdc = address(34_536_543);

    function setUp() public virtual override {
        super.setUp();
        
        vm.startPrank(admin);
        priceFeed = new ChainlinkPriceFeed();
        // loanManager = new LoanManagerMock(admin);
        nstblVault = new NSTBLVaultMock(address(priceFeed));
        nstblToken = new NSTBLTokenMock("NSTBL Token", "NSTBL", admin);
        Atvl = new ATVL(admin);
        atvl = address(Atvl);
        stakePool = new NSTBLStakePool(
            admin,
            address(nstblToken),
            address(nstblVault),
            nealthyAddr,
            // address(loanManager.lUSDC()),
            // address(loanManager.lUSDT()),
            address(loanManager)
            // address(priceFeed)
            );
        nstblToken.setStakePool(address(stakePool));
        stakePool.init(atvl, 900, 4000);
        stakePool.configurePool(250, 30, 5000);
        stakePool.configurePool(350, 60, 3000);
        stakePool.configurePool(400, 90, 1000);
        // loanManager.initializeTime();
        vm.stopPrank();
        console.log("stakePool: ", address(stakePool));
    }

    // function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
    //     vm.startPrank(account_);
    //     IERC20Helper(asset_).safeTransfer(destination_, amount_);
    //     vm.stopPrank();
    // }

    function _stakeNstbl(uint256 _amount, uint256 _poolId, address _user) internal {
        erc20_transfer(address(nstblToken), admin, nealthyAddr, _amount);
        vm.startPrank(nealthyAddr);
        nstblToken.approve(address(stakePool), _amount);
        stakePool.stake(_amount, _user, _poolId);
        vm.stopPrank();
    }
}
