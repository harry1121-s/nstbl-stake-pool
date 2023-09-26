pragma solidity 0.8.21;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceFeed {
    AggregatorV3Interface public dataFeed;
    address public USDT_FEED = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address public USDC_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public DAI_FEED = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;

    function getUSDCPrice() external view returns (uint256 price) {
        (, int p,,,) = AggregatorV3Interface(USDC_FEED).latestRoundData();
        price = uint256(p);
    }

    function getUSDTPrice() external view returns (uint256 price) {
        (, int p,,,) = AggregatorV3Interface(USDT_FEED).latestRoundData();
        price = uint256(p);
    }

    function getAverageAssetsPrice() external view returns (uint256 price) {

        (, int price1,,,) = AggregatorV3Interface(USDT_FEED).latestRoundData();
        (, int price2,,,) = AggregatorV3Interface(USDC_FEED).latestRoundData();
        (, int price3,,,) = AggregatorV3Interface(DAI_FEED).latestRoundData();
        price = uint256((price1 + price2 + price3) / 3);

    }
}
