// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import {Dealer} from "./TestDealer.sol";
import {Vault} from "./TestVault.sol";

/**
 * @title Blackjack.sol
 * @author 0xjomahe
 * @notice This is a contract implementing the functionality of the game
 * Blackjack.
 */
contract Blackjack is Ownable {
    // TODO: Look into throwing errors to save gas instead of require()
    event Hit(uint8);
    event Split(uint8);
    event Win(uint8, uint8);
    event Paid(uint256);
    event Push(uint8, uint8);
    event Bust(uint8, uint8);
    event Loss(uint8, uint8);
    event PlayerBlackjack(uint8);

    struct Hand {
        uint256 doubleDownAmount;
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
    Vault public vault;
    address public player;
    bool public paidOut;

    constructor(address payable _vault, address _dealer) payable {
        require(msg.value > 0, "Need to place an initial bet!");
        /*
           Set up the vault, generate random numbers for the hands and
           populate game data
        */
        vault = Vault(_vault);
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
        paidOut = false;
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
        if (_insurance) buyInsurance();
        gameData.hands[handNum].firstTurn = false;
        // Generate random number, add new card to hand and update handSum
        uint8 newCard = uint8(dealer.random() % 13) + 1;
        gameData.hands[handNum].cards.push(newCard);

        // Player busts
        if (isBusted(handNum, false)) {
            emit Bust(
                handNum,
                newCard +
                    gameData.hands[handNum].cards[0] +
                    gameData.hands[handNum].cards[1]
            );
            // Dealer need not draw cards if the player has already busted
            payout(21);
        }

        emit Hit(
            newCard +
                gameData.hands[handNum].cards[0] +
                gameData.hands[handNum].cards[1]
        );
        return newCard;
    }

    function markFinished(bool _h0, bool _h1, bool _h2, bool _h3) external {
        gameData.hands[0].finished = _h0;
        gameData.hands[1].finished = _h1;
        gameData.hands[2].finished = _h2;
        gameData.hands[3].finished = _h3;
    }

    function stand(bool _insurance) external payable onlyPlayer {
        // Need to make sure all hands are complete before revealing dealer's cards
        GameData memory _gameData = gameData;
        for (uint i; i < _gameData.nextOpenHandSlot; ++i) {
            require(_gameData.hands[i].finished, "Not all hands are finished!");
        }

        if (_insurance) buyInsurance();

        // Dealer draws second card, keeps drawing until bust or sum greater than player's
        uint256 draws = dealer.random();
        // uint8 currSum = _gameData.dealerHand.cards[0];

        // TODO: uncomment the above line after testing:
        uint8 currSum = getHandSum(0, true);

        while (currSum <= 21) {
            // Dealer is forced to stop hitting at hard 17 or above
            if (currSum >= 18 || (currSum == 17 && !gameData.dealerHand.soft)) {
                break;
            }
            uint8 card = min(uint8((draws % 13) + 1), 10);
            draws /= 100;
            gameData.dealerHand.cards.push(card);

            currSum = getHandSum(0, true);
        }

        uint8 playerHandVal;
        for (uint8 handNum; handNum < _gameData.nextOpenHandSlot; ++handNum) {
            // Need to mark all the hands as being acted on
            playerHandVal = getHandSum(handNum, false);
            gameData.hands[handNum].firstTurn = false;
            if (currSum == playerHandVal) {
                emit Push(handNum, playerHandVal);
            } else {
                if (currSum > 21 || playerHandVal > currSum) {
                    emit Win(handNum, playerHandVal);
                } else {
                    emit Loss(handNum, playerHandVal);
                }
            }
            if (playerHandVal == 21) emit PlayerBlackjack(handNum);
        }
        payout(currSum);
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
        require(cards[0] == cards[1], "Need a pair in hand");
        require(msg.value == gameData.betAmount, "Need to match original bet");
        require(gameData.nextOpenHandSlot < 4, "Can only split to four hands");

        // Draw new cards for both hands
        uint newCards = dealer.random();
        uint8 firstCard = uint8((newCards % 13) + 1);
        gameData.hands[handNum].cards[1] = firstCard;

        uint8[] memory newHand = new uint8[](2);
        uint8 secondCard = uint8(((newCards / 100) % 13) + 1);
        newHand[0] = cards[1];
        newHand[1] = secondCard;

        gameData.hands[gameData.nextOpenHandSlot++] = Hand({
            doubleDownAmount: 0,
            cards: newHand,
            soft: false,
            firstTurn: true,
            finished: false
        });

        emit Split(cards[0]);
    }

    function buyInsurance() internal {
        /**
         * We should allow players to buy insurance whenever they want since it
         * represents a positive expected outcome for the house and because of
         * the use of infinite decks, the odds of card draws are static
         */
        GameData memory _gameData = gameData;
        require(
            _gameData.dealerHand.cards[0] == 1 &&
                msg.value == _gameData.betAmount
        );
        gameData.insurance = true;
        // We don't increase the bet amount here; just check at the time of payout
    }

    function doubleDown(uint8 handNum) external payable {
        /** We allow the player to double down on the first action of each hand
         *  if it has a value of 9, 10, or 11.
         */
        GameData memory _gameData = gameData;
        uint8 handVal = getHandSum(handNum, false);
        require(
            _gameData.hands[handNum].firstTurn &&
                handVal <= 11 &&
                handVal >= 9 &&
                msg.value <= _gameData.betAmount
        );
        gameData.hands[handNum].doubleDownAmount = msg.value;
    }

    function isBusted(uint8 handNum, bool _dealer) internal returns (bool) {
        return (getHandSum(handNum, _dealer) > 21);
    }

    // TODO: mark internal when finished testing
    function getHandSum(uint8 handNum, bool _dealer) public returns (uint8) {
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
        if (!_dealer) {
            gameData.hands[handNum].soft = (handSum > 11 && aces > 0);
        } else {
            gameData.dealerHand.soft = (handSum > 11 && aces > 0);
        }

        return handSum;
    }

    // TODO: Update payout function to pay out all hands at once since player can only stand once
    function payout(uint8 dealerHand) internal {
        require(!paidOut, "Player already paid out!");
        paidOut = true;
        GameData memory _gameData = gameData;
        /**
         * If the player wins, we send them back their original bet along with
         * their winnings. If the player wins on a blackjack, their payout is
         * 1.5x their original bet.
         */
        uint256 betSize = _gameData.betAmount;
        uint256 amountToPay;
        uint8 playerHand;

        for (uint8 handNum; handNum < _gameData.nextOpenHandSlot; ++handNum) {
            playerHand = getHandSum(handNum, false);

            if (playerHand > dealerHand && !isBusted(handNum, false)) {
                if (playerHand <= 21) {
                    unchecked {
                        // Natural blackjack is paid out at 3:2
                        amountToPay += (playerHand == 21 &&
                            _gameData.hands[handNum].cards.length == 2)
                            ? (betSize >> 1) * 5
                            : (betSize << 1);
                    }
                }
            } else if (playerHand == dealerHand) {
                amountToPay += betSize;
            }

            // If the player doubled down on this hand we pay them their double down amount
            amountToPay += (_gameData.hands[handNum].doubleDownAmount << 1);
        }

        // If the player wins their insurance bet they're paid out at 2:1
        if (
            _gameData.dealerHand.cards.length == 2 &&
            dealerHand == 21 &&
            _gameData.insurance
        ) {
            amountToPay += (betSize << 1);
        }

        /**
         * Methods for payout:
         * 1: transfer all balance from contract to vault, payout from vault (custody of funds)
         * 2: calculate funds needed from vault, payout from balance of contract and vault (extra gas)
         * 3: Payout from vault, send contract funds to vault (might not have enough in vault)
         */
        // Using payout option #1 since 1 and 2 have a few overlapping cases

        (bool sent, ) = payable(address(vault)).call{
            value: address(this).balance
        }("");

        require(sent, "Not sent to vault");
        if (amountToPay > 0) {
            emit Paid(amountToPay);
            vault.payoutFromVault(amountToPay, player);
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

    function setDealerCards(uint8 _card1, uint8 _card2) external {
        gameData.dealerHand.cards[0] = _card1;
        gameData.dealerHand.cards.push(_card2);
    }

    function addPlayerCards(uint8[] calldata _cards, uint8 handNum) external {
        for (uint i; i < _cards.length; ++i) {
            gameData.hands[handNum].cards.push(_cards[i]);
        }
    }
}
