// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Blackjack is ERC721, Ownable {
    struct GameData {
        uint256 betAmount;
        bool firstTurn;
        bool insurance;
        uint8[4] handSums;
        uint8[4][] hands;
    }
    GameData gameData;
    address immutable vault;
    uint256 public totalSupply;

    constructor(address _vault) payable ERC721("blackjack", "BJK") {
        require(msg.value >= 0, "Need to place an initial bet!");
        /*
           Set up the vault, generate random numbers for the hands and
           populate game data
        */
        vault = _vault;

        gameData.betAmount = msg.value;
        gameData.insurance = false;
        gameData.firstTurn = true;
    }

    function hit(bool _insurance, uint256 handNum) external payable {
        // Function logic
        if (_insurance) {
            require(gameData.firstTurn && msg.value == gameData.betAmount);
            gameData.insurance = true;
            gameData.betAmount <<= 1;
        }
        // Generate random number, add new card to hand and update handSum

        // Player busts
        if (isBusted(handNum)) {}
    }

    function stand(uint256 handNum) external payable {}

    function split(uint handNum) external payable {}

    function isBusted(uint256 handNum) internal view returns (bool) {
        return gameData.handSums[handNum] > 21;
    }
}
