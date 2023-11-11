// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILoanManager {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function getInvestedAssets(address _assets) external view returns (uint256);
    function getMaturedAssets() external view returns (uint256);
    function awaitingRedemption() external view returns (bool);
}
