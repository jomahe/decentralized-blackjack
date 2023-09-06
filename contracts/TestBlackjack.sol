// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import {Dealer} from "./TestDealer.sol";

/**
 * @title Blackjack.sol
 * @author 0xjomahe
 * @notice This is a contract implementing the functionality of the game
 * Blackjack.
 */
contract Blackjack is Ownable {
    event Hit();
    event Win();
    event Bust();

    struct Hand {
        uint8[] cards;
        bool soft;
        bool firstTurn;
    }
    struct GameData {
        Hand[4] hands;
        uint256 betAmount;
        Hand dealerHand;
        bool insurance;
    }
    GameData gameData;
    Dealer dealer;
    address immutable vault;
    uint256 public totalSupply;

    constructor(address _vault, address _dealer) payable {
        require(msg.value >= 0, "Need to place an initial bet!");
        /*
           Set up the vault, generate random numbers for the hands and
           populate game data
        */
        vault = _vault;
        dealer = Dealer(_dealer);

        uint cardDraw = dealer.random();

        unchecked {
            uint8 pCardOne = uint8(cardDraw % 13) + 1;
            gameData.hands[0].cards.push(pCardOne);
            gameData.dealerHand.cards.push(uint8(((cardDraw / 100) % 13) + 1));
            uint8 pCardTwo = uint8((cardDraw / 10000) % 13) + 1;
            gameData.hands[0].cards.push(pCardTwo);
        }

        gameData.betAmount = msg.value;
        gameData.insurance = false;
        gameData.hands[0].firstTurn = true;
    }

    function hit(bool _insurance, uint8 handNum) external payable {
        // Function logic
        if (_insurance) {
            require(
                gameData.hands[handNum].firstTurn &&
                    msg.value == gameData.betAmount
            );
            gameData.insurance = true;
            gameData.betAmount <<= 1;
        }
        // Generate random number, add new card to hand and update handSum
        uint8 newCard = uint8(dealer.random() % 13) + 1;
        gameData.hands[handNum].cards.push(newCard);

        // Player busts
        if (isBusted(handNum, false)) {
            emit Bust();
        }
    }

    function stand(uint8 handNum) external {
        // Dealer draws second card, keeps drawing until bust or sum greater than player's
        uint256 draws = dealer.random();
        uint8 playerHand = getHandSum(handNum, false);
        uint8 currSum = gameData.dealerHand.cards[0];

        while (currSum <= min(21, playerHand)) {
            // Dealer must stop at hard 17 or above
            if (currSum >= 18 || (currSum == 17 && !gameData.dealerHand.soft)) {
                break;
            }
            uint8 card = min(uint8((draws % 13) + 1), 10);
            draws /= 100;
            gameData.dealerHand.cards.push(card);

            currSum = getHandSum(0, true);
        }

        // Dealer busts
        if (currSum > 21) emit Win();
    }

    // TODO: Implement the split function
    function split(uint handNum) external payable {}

    function isBusted(uint8 handNum, bool _dealer) internal returns (bool) {
        return (getHandSum(handNum, _dealer) > 21);
    }

    function getHandSum(uint8 handNum, bool _dealer) internal returns (uint8) {
        uint8 handSum;
        uint8[] memory hand = _dealer
            ? gameData.dealerHand.cards
            : gameData.hands[handNum].cards;
        uint8 numCards = uint8(hand.length);

        for (uint i; i < numCards; ++i) {
            // Add aces at the end due to dynamic valuation
            uint8 card = hand[i];
            if (card != 1) handSum = card >= 10 ? handSum + 10 : handSum + card;
        }

        uint8 aces = numAces(handNum, numCards, _dealer);

        /**
         * TODO: Need to update the logic on soft hands
         */

        gameData.hands[handNum].soft = false;
        for (uint j; j < aces; ++j) {
            if (handSum + 11 + (aces - j) >= 21) {
                ++handSum;
                gameData.hands[handNum].soft = true;
            } else {
                handSum += 11;
            }
        }
        return handSum;
    }

    function numAces(
        uint8 handNum,
        uint8 cards,
        bool _dealer
    ) internal view returns (uint8) {
        uint8[] memory hand = _dealer
            ? gameData.dealerHand.cards
            : gameData.hands[handNum].cards;
        uint8 aces;
        unchecked {
            for (uint i; i < cards; ++i) {
                if (hand[i] == 1) ++aces;
            }
        }
        return aces;
    }

    function min(uint8 a, uint8 b) public pure returns (uint8) {
        return (a < b) ? a : b;
    }
}
