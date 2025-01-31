// SPDX-License-Identifier: MIT  
pragma solidity ^0.8.0;  

contract TimeBasedContract {  
    struct Deposit {  
        uint256 amount;  
        uint256 releaseTime;  
    }  

    mapping(address => Deposit) public deposits;  

    // Event to log deposits  
    event Deposited(address indexed user, uint256 amount, uint256 releaseTime);  
    event Withdrawn(address indexed user, uint256 amount);  

    // Function to deposit Ether  
    function deposit(uint256 _lockTime) external payable {  
        require(msg.value > 0, "Must send Ether");  
        require(deposits[msg.sender].amount == 0, "Existing deposit found");  

        uint256 releaseTime = block.timestamp + _lockTime;  
        deposits[msg.sender] = Deposit(msg.value, releaseTime);  

        emit Deposited(msg.sender, msg.value, releaseTime);  
    }  

    // Function to withdraw Ether after the lock period  
    function withdraw() external {  
        Deposit storage userDeposit = deposits[msg.sender];  
        require(userDeposit.amount > 0, "No deposit found");  
        require(block.timestamp >= userDeposit.releaseTime, "Funds are still locked");  

        uint256 amount = userDeposit.amount;  
        userDeposit.amount = 0; // Reset deposit amount to prevent re-entrancy attacks  
        payable(msg.sender).transfer(amount);  

        emit Withdrawn(msg.sender, amount);  
    }  

    // Function to check the lock time remaining  
    function timeRemaining() external view returns (uint256) {  
        Deposit storage userDeposit = deposits[msg.sender];  
        if (userDeposit.amount == 0) {  
            return 0;  
        }  
        if (block.timestamp >= userDeposit.releaseTime) {  
            return 0;  
        }  
        return userDeposit.releaseTime - block.timestamp;  
    }  
}
