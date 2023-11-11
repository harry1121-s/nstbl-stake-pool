// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./TokenLPMock.sol";
import { console } from "forge-std/Test.sol";

contract LoanManagerMock {
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // uint256 public interest = 158_548_961;
    uint256 public interest = 158_548_961;
    address public admin;
    uint256 public investedAssets;
    uint256 public rewards;
    uint256 public extraDeposit;
    uint256 public removedAssets;
    uint256 public redeemedAssets;
    uint256 public startTime;
    TokenLPMock public lUSDC;
    TokenLPMock public lUSDT;
    mapping(address => bool) awaitingRedemption;

    constructor(address _admin) {
        admin = _admin;
    }

    function initializeTime() external {
        startTime = block.timestamp;
    }

    function addAssets(uint256 _assets) external {
        extraDeposit = _assets;
    }

    function deposit(address _asset, uint256 _amount) external { 
        investedAssets += _amount;
    }

    function getAwaitingRedemptionStatus(address _asset) external view returns (bool) {
        return awaitingRedemption[_asset];
    }

    function updateAwaitingRedemption(address _asset, bool _value) external {
        awaitingRedemption[_asset] = _value;
    }

    function removeAssets(uint256 _assets) external {
        removedAssets = _assets;
    }

    function updateInvestedAssets(uint256 _investedAssets) external {
        investedAssets = _investedAssets;
    }

    function updateRedeemedAssets(uint256 _redeemedAssets) external {
        redeemedAssets = _redeemedAssets;
    }

    function getInvestedAssets(address _asset) external view returns (uint256) {
        return investedAssets + extraDeposit - removedAssets;
    }

    function getMaturedAssets(address _asset) external view returns (uint256 _value) {
        _value = extraDeposit + (investedAssets + ((investedAssets * (block.timestamp - startTime) * interest) / 1e17)) - redeemedAssets;
    }

    // function getMaturedAssets(address _asset) external view returns(uint256) {
    //     return investedAssets;
    // }

    function updateRewards(uint256 _rewards) external {
        rewards = _rewards;
    }

    function rebalanceInvestedAssets() external {
        console.log("Rebalancing");
        console.log("Invested Assets: ", investedAssets);
        console.log("Extra Deposit: ", extraDeposit);
        console.log("Removed Assets: ", removedAssets);
        investedAssets = (investedAssets + extraDeposit) - removedAssets;
        extraDeposit = 0;
        removedAssets = 0;
        console.log("Invested Assets After: ", investedAssets);
    }
}
