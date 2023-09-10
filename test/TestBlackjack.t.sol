// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {Blackjack} from "../src/TestBlackjack.sol";
import {Dealer} from "../src/TestDealer.sol";

contract ConstructorTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            address(0x0),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));

        // Setting up initial hands
        uint draws = uint(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    _dealer.counter
                )
            )
        );

        playerCards[1] = uint8((draws % 13) + 1);
        playerCards[0] = uint8((draws / 10000) % 13) + 1;
        // playerHand = Blackjack.Hand({
        //     cards: playerCards,
        //     soft: false,
        //     firstTurn: true,
        //     finished: false
        // });

        dealerCards[0] = uint8(((draws / 100) % 13) + 1);
    }

    function testFailNoValue() public {
        Blackjack blackjack2 = new Blackjack{value: 0}(
            address(0x0),
            address(_dealer)
        );
        blackjack2.getBetAmount();
    }

    function testInitValues() public {
        uint draws = uint(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    _dealer.counter
                )
            )
        );
        uint8[] memory actualPlayerCards = blackjack.getCardsFromHand(0);
        uint8[] memory actualDealerCards = blackjack.getDealerCards();

        assertEq(actualPlayerCards[1], uint8((draws % 13) + 1));
        assertEq(actualPlayerCards[0], uint8((draws / 10000) % 13) + 1);
        assertEq(actualDealerCards[0], uint8(((draws / 10000) % 13) + 1));
    }

    // function testInitialGameData() public {
    //     assertEq(blackjack.gameData, (newHand, 1 ether, ));
    //     assertEq(blackjack.getBetAmount(), 1 ether);
    //     assertEq(blackjack.getInsurance(), false);
    //     assertEq(blackjack.getNextOpenHandSlot(), 1);
    //     assertEq(blackjack.gameData.hands[0].firstTurn, true);
    // }

    // function testInitialHand() public {
    //     uint hand = uint(
    //         keccak256(
    //             abi.encodePacked(
    //                 block.difficulty,
    //                 block.timestamp,
    //                 _dealer.counter
    //             )
    //         )
    //     );
    //     unchecked {
    //         uint8 pCardOne = uint8(hand % 13) + 1;
    //         uint8 dealHand = uint8(((hand / 100) % 13) + 1);
    //         uint8 pCardTwo = uint8((hand / 10000) % 13) + 1;

    //         assertEq(blackjack.gameData.dealerHand.cards[0], dealHand);
    //         assertEq(blackjack.gameData.hands[0].cards[0], pCardOne);
    //         assertEq(blackjack.gameData.hands[0].cards[1], pCardTwo);
    //     }
    // }
}
