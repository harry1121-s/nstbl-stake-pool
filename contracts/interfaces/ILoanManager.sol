// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILoanManager {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function getInvestedAssets(address _assets) external view returns (uint256);
    function getMaturedAssets(address _assets) external view returns (uint256);
}
