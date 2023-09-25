// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILoanManager {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function getAssets(address _asset, uint256 _lpTokens) external view returns (uint256);
    function getAssetsWithUnrealisedLosses(address _asset, uint256 _lpTokens) external view returns (uint256);
}
