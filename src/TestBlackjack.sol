// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import {Dealer} from "./TestDealer.sol";

/**
 * @title Blackjack.sol
 * @author 0xjomahe
 * @notice This is a contract implementing the functionality of the game
 * Blackjack.
 */
contract Blackjack is Ownable {
    event Hit(uint8);
    event Split();
    event Win();
    event Paid();
    event Bust(uint8);

    struct Hand {
        uint8[] cards;
        bool soft;
        bool firstTurn;
        bool finished;
    }
    struct GameData {
        Hand[4] hands;
        uint256 betAmount;
        Hand dealerHand;
        uint8 nextOpenHandSlot;
        bool insurance;
    }
    GameData public gameData;
    Dealer public dealer;
    address public vault;
    address public player;

    constructor(address _vault, address _dealer) payable {
        require(msg.value > 0, "Need to place an initial bet!");
        /*
           Set up the vault, generate random numbers for the hands and
           populate game data
        */
        vault = _vault;
        dealer = Dealer(_dealer);
        player = msg.sender;

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
        gameData.nextOpenHandSlot = 1;
    }

    modifier handValid(uint8 handNum) {
        require(gameData.hands[handNum].cards.length != 0, "Hand invalid");
        _;
    }

    modifier onlyPlayer() {
        require(msg.sender == player, "Must be player to call function");
        _;
    }

    function hit(
        bool _insurance,
        uint8 handNum
    ) external payable onlyPlayer handValid(handNum) returns (uint8) {
        // Function logic
        if (_insurance) {
            require(
                gameData.hands[handNum].firstTurn &&
                    msg.value == gameData.betAmount &&
                    gameData.dealerHand.cards[0] == 1 &&
                    !gameData.hands[handNum].finished
            );
            gameData.insurance = true;
            gameData.betAmount <<= 1;
        }
        // Generate random number, add new card to hand and update handSum
        uint8 newCard = uint8(dealer.random() % 13) + 1;
        gameData.hands[handNum].cards.push(newCard);

        // Player busts
        if (isBusted(handNum, false)) {
            emit Bust(
                newCard +
                    gameData.hands[handNum].cards[0] +
                    gameData.hands[handNum].cards[1]
            );
            gameData.hands[handNum].finished = true;
            // payout(msg.sender, handNum, getHandSum(handNum, false));
        }

        emit Hit(
            newCard +
                gameData.hands[handNum].cards[0] +
                gameData.hands[handNum].cards[1]
        );
        return newCard;
    }

    function stand(uint8 handNum) external onlyPlayer handValid(handNum) {
        // Dealer draws second card, keeps drawing until bust or sum greater than player's
        uint256 draws = dealer.random();
        uint8 playerHand = getHandSum(handNum, false);
        uint8 currSum = gameData.dealerHand.cards[0];

        while (currSum <= min(21, playerHand)) {
            // Dealer os forced to stop hitting at hard 17 or above
            if (currSum >= 18 || (currSum == 17 && !gameData.dealerHand.soft)) {
                break;
            }
            uint8 card = min(uint8((draws % 13) + 1), 10);
            draws /= 100;
            gameData.dealerHand.cards.push(card);

            currSum = getHandSum(0, true);
        }

        // Player wins if their hand value is greater than the dealer's
        if (currSum > 21 || playerHand > currSum) {
            payout(msg.sender, handNum, playerHand);
            emit Win();
        } else if (playerHand == currSum) {}
    }

    /**
     * Player allowed to split their hand only if they were dealt a pair.
     * They must place the same bet for the second hand and each of the two
     * starts with one of the pair cards. They draw a second card for each hand.
     */
    function split(
        uint8 handNum
    ) external payable onlyPlayer handValid(handNum) {
        uint8[] memory cards = gameData.hands[handNum].cards;
        require(cards[0] == cards[1]);
        require(msg.value == gameData.betAmount);
        require(gameData.nextOpenHandSlot < 4); // Can only split to four hands

        // Draw new cards for both hands
        uint newCards = dealer.random();
        uint8 firstCard = uint8((newCards % 13) + 1);
        gameData.hands[handNum].cards[1] = firstCard;

        uint8[] memory newHand = new uint8[](2);
        uint8 secondCard = uint8(((newCards / 100) % 13) + 1);
        newHand[0] = cards[1];
        newHand[1] = secondCard;

        gameData.hands[gameData.nextOpenHandSlot++] = Hand({
            cards: newHand,
            soft: false,
            firstTurn: true,
            finished: false
        });

        emit Split();
    }

    function isBusted(uint8 handNum, bool _dealer) internal returns (bool) {
        return (getHandSum(handNum, _dealer) > 21);
    }

    function getHandSum(uint8 handNum, bool _dealer) internal returns (uint8) {
        uint8 handSum;
        uint8[] memory hand = _dealer
            ? gameData.dealerHand.cards
            : gameData.hands[handNum].cards;
        uint8 numCards = uint8(hand.length);
        uint8 aces;
        for (uint i; i < numCards; ++i) {
            // Add aces at the end due to dynamic valuation
            uint8 card = hand[i];
            if (card != 1) {
                handSum = card >= 10 ? handSum + 10 : handSum + card;
            } else {
                ++aces;
            }
        }

        for (uint j; j < aces; ++j) {
            if (handSum + 11 + (aces - j - 1) > 21) {
                ++handSum;
            } else {
                handSum += 11;
            }
        }
        gameData.hands[handNum].soft = (handSum > 11 && aces > 0);
        return handSum;
    }

    function payout(address winner, uint8 handNum, uint8 playerHand) internal {
        require(!gameData.hands[handNum].finished);
        /**
         * If the player wins, we send them back their original bet along with
         * their winnings. If the player wins on a blackjack, their payout is
         * 1.5x their original bet.
         */
        if (playerHand <= 21) {
            unchecked {
                uint256 amountToPay = (playerHand == 21)
                    ? (gameData.betAmount >> 2) * 5
                    : (gameData.betAmount << 2);
                payable(winner).transfer(amountToPay);
                emit Paid();
            }
        } else {
            payable(vault).transfer(gameData.betAmount);
        }
    }

    function min(uint8 a, uint8 b) internal pure returns (uint8) {
        return (a < b) ? a : b;
    }

    /** /////////////////////////////////////////
     *  FUNCTIONS FOR TESTING
     */ /////////////////////////////////////////
    function getBetAmount() external view returns (uint256) {
        return gameData.betAmount;
    }

    function getNextOpenHandSlot() external view returns (uint8) {
        return gameData.nextOpenHandSlot;
    }

    function getInsurance() external view returns (bool) {
        return gameData.insurance;
    }

    function getHands() external view returns (Hand[4] memory) {
        return gameData.hands;
    }

    function getCardsFromHand(
        uint8 handNum
    ) external view returns (uint8[] memory) {
        return gameData.hands[handNum].cards;
    }

    function getDealerCards() external view returns (uint8[] memory) {
        return gameData.dealerHand.cards;
    }

    function setPlayerCards(uint8 _card1, uint8 _card2, uint8 handNum) public {
        gameData.hands[handNum].cards[0] = _card1;
        gameData.hands[handNum].cards[1] = _card2;
    }

    function setDealerCard(uint8 _card) external {
        gameData.dealerHand.cards[0] = _card;
    }
}
