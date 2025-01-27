// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnhancedAuction {
    struct Auction {
        address payable owner;
        uint endTime;
        uint highestBid;
        address highestBidder;
        uint reservePrice;
        bool ended;
        bool paused;
        mapping(address => uint) pendingReturns;
        address[] whitelist; // List of approved bidders
    }

    uint public auctionCount;
    mapping(uint => Auction) public auctions;
    mapping(uint => address) public winners; // Track winners of past auctions
    mapping(uint => uint) public winningBids; // Track winning bid amounts

    // Events
    event AuctionCreated(uint auctionId, uint endTime, uint reservePrice);
    event AuctionPaused(uint auctionId);
    event AuctionResumed(uint auctionId);
    event BidPlaced(uint auctionId, address bidder, uint amount);
    event AuctionEnded(uint auctionId, address winner, uint amount);
    event Withdrawal(uint auctionId, address bidder, uint amount);

    // Modifier to restrict access to the auction owner
    modifier onlyAuctionOwner(uint auctionId) {
        require(msg.sender == auctions[auctionId].owner, "Only auction owner can call this.");
        _;
    }

    // Modifier to check if auction is active
    modifier isActive(uint auctionId) {
        require(block.timestamp <= auctions[auctionId].endTime, "Auction has ended.");
        require(!auctions[auctionId].paused, "Auction is paused.");
        _;
    }

    // Modifier to check if auction exists
    modifier auctionExists(uint auctionId) {
        require(auctionId > 0 && auctionId <= auctionCount, "Auction does not exist.");
        _;
    }

    // Create a new auction
    function createAuction(uint _biddingTime, uint _reservePrice, address[] calldata _whitelist) external {
        auctionCount++;
        Auction storage newAuction = auctions[auctionCount];
        newAuction.owner = payable(msg.sender);
        newAuction.endTime = block.timestamp + _biddingTime;
        newAuction.reservePrice = _reservePrice;
        newAuction.paused = false;
        newAuction.ended = false;
        newAuction.whitelist = _whitelist;

        emit AuctionCreated(auctionCount, newAuction.endTime, _reservePrice);
    }

    // Place a bid
    function bid(uint auctionId) external payable auctionExists(auctionId) isActive(auctionId) {
        Auction storage auction = auctions[auctionId];

        // Check if bidder is whitelisted
        if (auction.whitelist.length > 0) {
            bool isWhitelisted = false;
            for (uint i = 0; i < auction.whitelist.length; i++) {
                if (auction.whitelist[i] == msg.sender) {
                    isWhitelisted = true;
                    break;
                }
            }
            require(isWhitelisted, "You are not whitelisted to participate in this auction.");
        }

        require(msg.value > auction.highestBid, "Bid is not high enough.");
        require(msg.value >= auction.reservePrice, "Bid is below the reserve price.");

        // Update highest bidder
        if (auction.highestBid != 0) {
            auction.pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        // Extend auction time if bid is close to the end (e.g., within 10 minutes)
        if (auction.endTime - block.timestamp < 10 minutes) {
            auction.endTime += 10 minutes;
        }

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    // Withdraw overbids
    function withdraw(uint auctionId) external auctionExists(auctionId) returns (bool) {
        Auction storage auction = auctions[auctionId];
        uint amount = auction.pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw.");

        // Reset pending amount before transfer to prevent re-entrancy attack
        auction.pendingReturns[msg.sender] = 0;

        if (!payable(msg.sender).send(amount)) {
            auction.pendingReturns[msg.sender] = amount;
            return false;
        }

        emit Withdrawal(auctionId, msg.sender, amount);
        return true;
    }

    // End the auction
    function endAuction(uint auctionId) external auctionExists(auctionId) onlyAuctionOwner(auctionId) {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "Auction has not ended yet.");
        require(!auction.ended, "Auction already ended.");

        auction.ended = true;

        // Record winner and transfer funds
        winners[auctionId] = auction.highestBidder;
        winningBids[auctionId] = auction.highestBid;

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);

        if (auction.highestBid != 0) {
            auction.owner.transfer(auction.highestBid);
        }
    }

    // Pause the auction
    function pauseAuction(uint auctionId) external auctionExists(auctionId) onlyAuctionOwner(auctionId) {
        Auction storage auction = auctions[auctionId];
        auction.paused = true;

        emit AuctionPaused(auctionId);
    }

    // Resume the auction
    function resumeAuction(uint auctionId) external auctionExists(auctionId) onlyAuctionOwner(auctionId) {
        Auction storage auction = auctions[auctionId];
        auction.paused = false;

        emit AuctionResumed(auctionId);
    }

    // Get auction details
    function getAuctionDetails(uint auctionId) external view auctionExists(auctionId) returns (
        address _owner,
        uint _endTime,
        uint _highestBid,
        address _highestBidder,
        uint _reservePrice,
        bool _ended,
        bool _paused
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.owner,
            auction.endTime,
            auction.highestBid,
            auction.highestBidder,
            auction.reservePrice,
            auction.ended,
            auction.paused
        );
    }
}
