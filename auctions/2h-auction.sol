// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiObjectAuction {
    struct Bid {
        address bidder;
        uint256 amount;
    }

    struct AuctionItem {
        uint256 itemId;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool isActive;
    }

    mapping(uint256 => AuctionItem) public auctionItems; // Mapping of item IDs to auction details
    mapping(uint256 => Bid[]) public bids; // Mapping of item IDs to bids
    address public owner;
    uint256 public auctionEndTime;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier auctionActive(uint256 itemId) {
        require(block.timestamp <= auctionEndTime, "Auction has ended");
        require(auctionItems[itemId].isActive, "Auction for this item is not active");
        require(block.timestamp <= auctionItems[itemId].endTime, "Bidding for this item has ended");
        _;
    }

    event NewBid(uint256 indexed itemId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed itemId, address winner, uint256 amount);

    constructor(uint256[] memory itemIds) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + 2 hours;

        for (uint256 i = 0; i < itemIds.length; i++) {
            auctionItems[itemIds[i]] = AuctionItem({
                itemId: itemIds[i],
                highestBid: 0,
                highestBidder: address(0),
                endTime: block.timestamp + 30 minutes,
                isActive: true
            });
        }
    }

    function placeBid(uint256 itemId) external payable auctionActive(itemId) {
        require(msg.value > auctionItems[itemId].highestBid, "Bid must be higher than the current highest bid");

        // Refund the previous highest bidder
        if (auctionItems[itemId].highestBidder != address(0)) {
            payable(auctionItems[itemId].highestBidder).transfer(auctionItems[itemId].highestBid);
        }

        // Update the highest bid and bidder
        auctionItems[itemId].highestBid = msg.value;
        auctionItems[itemId].highestBidder = msg.sender;

        bids[itemId].push(Bid({ bidder: msg.sender, amount: msg.value }));

        emit NewBid(itemId, msg.sender, msg.value);
    }

    function endAuction(uint256 itemId) external onlyOwner {
        require(block.timestamp > auctionItems[itemId].endTime, "Auction for this item is still ongoing");
        require(auctionItems[itemId].isActive, "Auction for this item has already ended");

        auctionItems[itemId].isActive = false;

        if (auctionItems[itemId].highestBidder != address(0)) {
            emit AuctionEnded(itemId, auctionItems[itemId].highestBidder, auctionItems[itemId].highestBid);
        }
    }

    function withdraw() external onlyOwner {
        require(block.timestamp > auctionEndTime, "Cannot withdraw before auction ends");

        // Transfer all remaining funds to the owner
        payable(owner).transfer(address(this).balance);
    }

    function getAuctionDetails(uint256 itemId) external view returns (AuctionItem memory) {
        return auctionItems[itemId];
    }
}