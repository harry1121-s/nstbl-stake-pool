// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../interfaces/IChainlinkPriceFeed.sol";

contract NSTBLVaultMock {
    address public chainlinkPriceFeed;

    uint256 public usdcLiquidity = 1e3 * 1e6;
    uint256 public usdtLiquidity = 1e3 * 1e6;

    constructor(address _chainlinkPriceFeed) {
        chainlinkPriceFeed = _chainlinkPriceFeed;
    }

    function getTvlLiquidAssets() external view returns (uint256 tvl) {
        tvl = usdcLiquidity * IChainlinkPriceFeed(chainlinkPriceFeed).getUSDCPrice()
            + usdtLiquidity * IChainlinkPriceFeed(chainlinkPriceFeed).getUSDTPrice();
    }
}
