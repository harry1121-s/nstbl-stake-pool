pragma solidity 0.8.21;

interface IChainlinkPriceFeed {
    
    function getLatestPrice() external view returns(int256 price);

    function getDecimals() external view returns (uint256 decimals);

    function getUSDCPrice() external view returns (int256 price);

    function getUSDTPrice() external view returns (int256 price);

    function getAverageAssetsPrice() external view returns (int256 price);
}
