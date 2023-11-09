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
    address public user4 = vm.addr(123443);
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public virtual override {
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
        stakePool.init(atvl, 285388127, [0,0,0], [0,0,0], [30,90,180]);
        loanManager.initializeTime();
        console.log("Total supply at setup: ", nstblToken.totalSupply());
        vm.stopPrank();
    }

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        console.log("Balance of account: ", IERC20Helper(asset_).balanceOf(account_));
        IERC20Helper(asset_).safeTransfer(destination_, amount_);
        vm.stopPrank();
    }

    function _stakeNSTBL(address _user, uint256 _amount, uint8 _trancheId) internal {
        // Add nSTBL balance to NSTBL_HUB
        deal(address(nstblToken), NSTBL_HUB, _amount);
        assertEq(IERC20Helper(address(nstblToken)).balanceOf(NSTBL_HUB), _amount);

        // Action = Stake
        vm.startPrank(NSTBL_HUB);
        IERC20Helper(address(nstblToken)).safeIncreaseAllowance(address(stakePool), _amount);
        stakePool.stake(_user, _amount, _trancheId);
        vm.stopPrank();
    }

    // function _checkStakePostCondition(
    //     bytes11 _stakeId,
    //     uint8 _trancheId,
    //     address _owner,
    //     uint256 _amount,
    //     uint256 _rewardDebt,
    //     uint256 _burnDebt,
    //     uint256 _stakeTimeStamp
    // ) internal {
    //     (
    //         bytes11 stakeId,
    //         uint8 trancheId,
    //         address owner,
    //         uint256 amount,
    //         uint256 rewardDebt,
    //         uint256 burnDebt,
    //         uint256 stakeTimeStamp
    //     ) = stakePool.stakerInfo(_stakeId);

    //     assertEq(stakeId, _stakeId, "check stakeId");
    //     assertEq(trancheId, _trancheId, "check trancheId");
    //     assertEq(owner, _owner, "check _owner");
    //     assertEq(amount, _amount, "check _amount");
    //     assertEq(rewardDebt, _rewardDebt, "check _rewardDebt");
    //     assertEq(burnDebt, _burnDebt,  "check _burnDebt" );
    //     assertEq(stakeTimeStamp, _stakeTimeStamp, "check _stakeTimeStamp");
    // }

    // function _printStakePostCondition(bytes11 _stakeId) internal {
    //     (
    //         bytes11 stakeId,
    //         uint8 trancheId,
    //         address owner,
    //         uint256 amount,
    //         uint256 rewardDebt,
    //         uint256 burnDebt,
    //         uint256 stakeTimeStamp
    //     ) = stakePool.stakerInfo(_stakeId);

    //     console.logBytes11(stakeId);
    //     console.log("trancheId:-      ", trancheId);
    //     console.log("owner:-          ", owner);
    //     console.log("amount:-         ", amount);
    //     console.log("rewardDebt:-     ", rewardDebt);
    //     console.log("burnDebt:-       ", burnDebt);
    //     console.log("stakeTimeStamp:- ", stakeTimeStamp);
    // }
    
    function _randomizeStakeIdAndIndex(bytes11 _stakeId, uint256 len) internal view returns (bytes11 randomStakeId, uint256 index) {
        bytes32 hashedVal = keccak256(abi.encodePacked(_stakeId, block.timestamp));
        randomStakeId = bytes11(hashedVal);
        index = uint256(hashedVal) % len;
        return (randomStakeId, index);
    }
}
