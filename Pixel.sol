pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: SimPL-2.0

import "./lib/String.sol";
import "./lib/Util.sol";
import "./lib/UInteger.sol";

import "./ERC721Ex.sol";

// nftSign  nftType     md5     version    size     mintTime   index
// 1        15          128     8          16       40         48
// 255      240         112     104        88       48         0

contract Pixel is ERC721Ex {
    using String for string;
    using UInteger for uint256;

    mapping(uint256 => string) internal names;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function mint(
        address to,
        uint256 nftType,
        uint256 version,
        uint256 size,
        uint256 md5,
        string memory data
    ) external {
        uint256 pixelId =
            NFT_SIGN_BIT |
                (uint256(uint16(nftType)) << 240) |
                (uint256(uint128(md5)) << 112) |
                (uint256(uint8(version)) << 104) |
                (uint256(uint16(size)) << 88) |
                (block.timestamp << 48) |
                (uint48(totalSupply + 1));

        _mint(to, pixelId);

        names[pixelId] = data;
    }

    function getName(uint256 pixelId) external view returns (string memory) {
        return names[pixelId];
    }

    function getNames(uint256[] memory pixelIds)
        external
        view
        returns (string[] memory)
    {
        string[] memory result = new string[](pixelIds.length);

        for (uint256 i = 0; i < pixelIds.length; i++) {
            result[i] = names[pixelIds[i]];
        }
        return result;
    }

    function tokenURI(uint256 pixelId)
        external
        view
        override
        returns (string memory)
    {
        bytes memory bs = abi.encodePacked(pixelId);

        return uriPrefix.concat("pixel/").concat(Util.base64Encode(bs));
    }
}
