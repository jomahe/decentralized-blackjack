// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
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

        emit log_uint(draws);

        playerCards[1] = uint8((draws % 13) + 1);
        playerCards[0] = uint8((draws / 10000) % 13) + 1;

        emit log_string("Experimental player cards: ");
        emit log_uint(playerCards[1]);
        emit log_uint(playerCards[0]);

        dealerCards[0] = uint8(((draws / 100) % 13) + 1);
        emit log_string("Experimental dealer cards: ");
        emit log_uint(dealerCards[0]);
    }

    function testFailNoValue() public {
        Blackjack blackjack2 = new Blackjack{value: 0}(
            address(0x0),
            address(_dealer)
        );
        blackjack2.getBetAmount();
    }

    // function testInitValues() public {
    //     uint draws = uint(
    //         keccak256(
    //             abi.encodePacked(
    //                 block.prevrandao,
    //                 block.timestamp,
    //                 _dealer.counter
    //             )
    //         )
    //     );
    //     uint8[] memory actualPlayerCards = blackjack.getCardsFromHand(0);
    //     emit log_string("Actual player cards: ");
    //     emit log_uint(actualPlayerCards[1]);
    //     emit log_uint(actualPlayerCards[0]);

    //     uint8[] memory actualDealerCards = blackjack.getDealerCards();
    //     emit log_string("Actual dealer cards: ");
    //     emit log_uint(actualDealerCards[0]);

    //     assertEq(actualPlayerCards[1], uint8((draws % 13) + 1));
    //     assertEq(actualPlayerCards[0], uint8((draws / 10000) % 13) + 1);
    //     assertEq(actualDealerCards[0], uint8(((draws / 10000) % 13) + 1));
    // }

    function testInitialGameData() public {
        assertEq(blackjack.getBetAmount(), 1 ether);
        assertEq(blackjack.getInsurance(), false);
        assertEq(blackjack.getNextOpenHandSlot(), 1);
        assertEq(blackjack.getHands()[0].firstTurn, true);
    }
}
