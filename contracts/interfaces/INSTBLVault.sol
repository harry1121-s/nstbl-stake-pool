// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface INSTBLVault {
    
    function getTvlLiquidAssets()external view returns(uint256 tvl);

}
