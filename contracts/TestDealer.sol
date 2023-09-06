// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Dealer {
    uint counter = 1;
    address owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function random() external onlyOwner returns (uint) {
        counter++;
        return
            uint(
                keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, counter)
                )
            );
    }
}
