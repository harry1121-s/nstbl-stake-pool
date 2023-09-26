// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { Test, console } from "forge-std/Test.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { NSTBLStakePool } from "../../contracts/StakePool.sol";
import { TokenLP } from "../../contracts/TokenLP.sol";
import {LoanManagerMock} from "../../contracts/mocks/LoanManagerMock.sol";
import {NSTBLVaultMock} from "../../contracts/mocks/NSTBLVaultMock.sol";
import {NSTBLTokenMock} from "../../contracts/mocks/NSTBLTokenMock.sol";
import { ChainlinkPriceFeed } from "../../contracts/chainlink/ChainlinkPriceFeed.sol";
import { IERC20Helper } from "../../contracts/interfaces/IERC20Helper.sol";

contract BaseTest is Test {
    using SafeERC20 for IERC20Helper;

    NSTBLStakePool public stakePool;
    ChainlinkPriceFeed public priceFeed;
    TokenLP public lpToken;
    LoanManagerMock public loanManager;
    NSTBLVaultMock public nstblVault;
    NSTBLTokenMock public nstblToken;

    address public admin = address(123);
    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public atvl = address(4);


    function setUp() public virtual {

        uint256 mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/CFhLkcCEs1dFGgg0n7wu3idxcdcJEgbW");
        vm.selectFork(mainnetFork);
        vm.startPrank(admin);
        priceFeed = new ChainlinkPriceFeed();
        loanManager = new LoanManagerMock(admin);
        nstblVault = new NSTBLVaultMock(address(priceFeed));
        nstblToken = new NSTBLTokenMock("NSTBL Token", "NSTBL", admin);
        
        stakePool = new NSTBLStakePool(
            admin,
            address(nstblToken),
            address(nstblVault),
            address(loanManager.lUSDC()),
            address(loanManager.lUSDT()),
            address(loanManager),
            address(priceFeed)
            );
        nstblToken.setStakePool(address(stakePool));
        vm.stopPrank();
    }

    function _init_StakePool() internal {
        stakePool.init(
            atvl,
            
        )
    }
}