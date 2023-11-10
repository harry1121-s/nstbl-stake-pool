// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IHandlerMain {
    function users(uint256 index) external returns (address);
    function numOfUsers() external returns (uint256);
}
