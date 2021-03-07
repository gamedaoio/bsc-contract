pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: SimPL-2.0

import "./interface/IERC20.sol";
import "./interface/IERC721.sol";
import "./interface/IERC721TokenReceiver.sol";

import "./lib/UInteger.sol";
import "./lib/Util.sol";

import "./Member.sol";

contract Market is Member, IERC721TokenReceiver {
    using UInteger for uint256;
    
    struct Retail {
        uint256 id;
        address owner;
        address nft;
        uint256 nftId;
        address money;
        uint256 price;
    }
    
    struct MoneyWhite {
        bool enabled;
        uint256 priceMin;
        uint256 feeRatio;
    }
    
    event Trade(uint256 indexed id, address indexed from, address indexed to,
        address nft, uint256 nftId, address money, uint256 price);
    
    uint256 public idCount = 0;
    Retail[] public retails;
    mapping(uint256 => uint256) public indexs;
    
    mapping(address => bool) public nftWhites;
    mapping(address => MoneyWhite) public moneyWhites;
    
    mapping(address => mapping(address => uint256)) public balances;
    
    function setNftWhite(address addr, bool enable)
        external CheckPermit("Config") {
        
        nftWhites[addr] = enable;
    }
    
    function setMoneyWhite(address addr, bool enable,
        uint256 priceMin, uint256 feeRatio)
        external CheckPermit("Config") {
        
        MoneyWhite storage moneyWhite = moneyWhites[addr];
        moneyWhite.enabled = enable;
        moneyWhite.priceMin = priceMin;
        moneyWhite.feeRatio = feeRatio;
    }
    
    function retailsLength() external view returns(uint256) {
        return retails.length;
    }
    
    function getRetails(uint256 startIndex, uint256 endIndex, uint256 resultLength,
        address owner, address nft, address money)
        external view returns(Retail[] memory) {
        
        if (endIndex == 0) {
            endIndex = retails.length;
        }
        
        require(startIndex <= endIndex, "invalid index");
        
        Retail[] memory result = new Retail[](resultLength);
        
        uint256 len = 0;
        for (uint256 i = startIndex; i != endIndex && len != resultLength; ++i) {
            Retail storage retail = retails[i];
            
            if (owner != address(0) && owner != retail.owner) {
                continue;
            }
            
            if (nft != address(0) && nft != retail.nft) {
                continue;
            }
            
            if (money != address(0) && money != retail.money) {
                continue;
            }
            
            result[len++] = retail;
        }
        
        return result;
    }
    
    function onERC721Received(address, address from,
        uint256 nftId, bytes memory data)
        external override returns(bytes4) {
        
        uint256 operate = uint8(data[0]);
        
        if (operate == 1) {
            uint256 money = 0;
            for (uint256 i = 1; i != 33; ++i) {
                money = (money << 8) | uint8(data[i]);
            }
            
            uint256 price = 0;
            for (uint256 i = 33; i != 65; ++i) {
                price = (price << 8) | uint8(data[i]);
            }
            
            _addRetail(from, msg.sender, nftId, address(money), price);
        } else {
            return 0;
        }
        
        return Util.ERC721_RECEIVER_RETURN;
    }
    
    function _addRetail(address owner, address nft, uint256 nftId,
        address money, uint256 price) internal {
        
        require(nftWhites[nft], "nft not in white list");
        
        MoneyWhite storage moneyWhite = moneyWhites[money];
        require(moneyWhite.enabled, "money not in white list");
        require(price >= moneyWhite.priceMin, "money price too low");
        
        Retail memory retail = Retail({
            id: ++idCount,
            owner: owner,
            nft: nft,
            nftId: nftId,
            money: money,
            price: price
        });
        
        indexs[retail.id] = retails.length;
        retails.push(retail);
        
        emit Trade(retail.id, address(0), owner, nft, nftId, money, price);
    }
    
    function removeRetail(uint256 id) external {
        uint256 index = indexs[id];
        Retail memory retail = retails[index];
        require(retail.id == id, "id not match");
        require(retail.owner == msg.sender, "you not own the retail");
        
        Retail storage tail = retails[retails.length - 1];
        
        indexs[tail.id] = index;
        delete indexs[id];
        
        retails[index] = tail;
        retails.pop();
        
        emit Trade(id, retail.owner, address(0),
            retail.nft, retail.nftId, retail.money, retail.price);
        
        IERC721(retail.nft).transferFrom(
            address(this), retail.owner, retail.nftId);
    }
    
    function buy(uint256 id) external payable {
        uint256 index = indexs[id];
        Retail memory retail = retails[index];
        require(retail.id == id, "id not match");
        
        Retail storage tail = retails[retails.length - 1];
        
        indexs[tail.id] = index;
        delete indexs[id];
        
        retails[index] = tail;
        retails.pop();
        
        emit Trade(id, retail.owner, msg.sender,
            retail.nft, retail.nftId, retail.money, retail.price);
        
        MoneyWhite storage moneyWhite = moneyWhites[retail.money];
        address payable feeAccount = payable(manager.members("feeAccount"));
        uint256 fee = retail.price.mul(moneyWhite.feeRatio).div(Util.UDENO);
        
        if (retail.money == address(~uint256(0))) {
            require(msg.value == retail.price, "invalid money amount");
            feeAccount.transfer(fee);
        } else {
            IERC20 money = IERC20(retail.money);
            require(money.transferFrom(msg.sender, address(this), retail.price),
                "transfer money failed");
            require(money.transfer(feeAccount, fee),
                "transfer money failed");
        }
        
        balances[retail.owner][retail.money] += retail.price.sub(fee);
        
        IERC721(retail.nft).transferFrom(
            address(this), msg.sender, retail.nftId);
    }
    
    function withdraw(address money) external {
        address payable owner = msg.sender;
        
        uint256 balance = balances[owner][money];
        require(balance > 0, "no balance");
        balances[owner][money] = 0;
        
        if (money == address(~uint256(0))) {
            owner.transfer(balance);
        } else {
            require(IERC20(money).transfer(owner, balance),
                "transfer money failed");
        }
    }
}
