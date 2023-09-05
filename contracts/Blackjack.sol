// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Dealer} from "./Dealer.sol";

contract Blackjack is ERC721, Ownable {
    struct GameData {
        uint256 betAmount;
        uint256 lastRequestId;
        bool firstTurn;
        bool insurance;
        uint8[4] handSums;
        uint8[4][] hands;
        uint8 dealerHand;
    }
    GameData gameData;
    Dealer dealer;
    address immutable vault;
    uint256 public totalSupply;

    constructor(
        address _vault,
        address _dealer
    ) payable ERC721("blackjack", "BJK") {
        require(msg.value >= 0, "Need to place an initial bet!");
        /*
           Set up the vault, generate random numbers for the hands and
           populate game data
        */
        vault = _vault;
        dealer = Dealer(_dealer);

        gameData.lastRequestId = dealer.requestRandomWords();
        gameData.betAmount = msg.value;
        gameData.insurance = false;
        gameData.firstTurn = false;

        // TODO: implement the startGame() function, requiring that the NFT is sent and we mint a new game state to the user's wallet
    }

    function startGame() external {}

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
