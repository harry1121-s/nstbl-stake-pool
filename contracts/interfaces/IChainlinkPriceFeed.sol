pragma solidity 0.8.21;

interface IChainlinkPriceFeed {

    function getUSDCPrice() external view returns (uint256 price);

    function getUSDTPrice() external view returns (uint256 price);

    function getAverageAssetsPrice() external view returns (uint256 price);
}
