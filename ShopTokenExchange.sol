pragma solidity ^0.7.0;

// SPDX-License-Identifier: SimPL-2.0

import "./shop/ShopExchange.sol";

contract ShopTokenExchange is ShopExchange {
    function buy(uint256 tokenAmount, uint256 quantity) external {
        _buyExchange(msg.sender, tokenAmount, quantity, 0);
    }
}
