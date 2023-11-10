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
    address public user4 = vm.addr(123_443);
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public destinationAddress = vm.addr(123_444);

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(owner);

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
        stakePool.init(atvl, 285_388_127, [300, 200, 100], [700, 500, 300], [30, 90, 180]);
        loanManager.initializeTime();
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
        stakePool.stake(_user, _amount, _trancheId, destinationAddress);
        vm.stopPrank();
    }

    function _randomizeStakeIdAndIndex(bytes11 _stakeId, uint256 len)
        internal
        view
        returns (bytes11 randomStakeId, uint256 index)
    {
        bytes32 hashedVal = keccak256(abi.encodePacked(_stakeId, block.timestamp));
        randomStakeId = bytes11(hashedVal);
        index = uint256(hashedVal) % len;
        return (randomStakeId, index);
    }
}
