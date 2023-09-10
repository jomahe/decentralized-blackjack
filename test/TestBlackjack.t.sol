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

contract HitTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Hit(uint8);
    event Bust(uint8);

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            address(0x0),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
    }

    function testInsuranceTrue() public {
        blackjack.setDealerCard(1);
        blackjack.hit{value: 1 ether}(true, 0);
    }

    function testInsuranceTrueNoValue() public {
        blackjack.setDealerCard(1);
        vm.expectRevert(bytes(""));
        blackjack.hit{value: 0}(true, 0);
    }

    function testInsuranceNoAce() public {
        blackjack.setDealerCard(2);
        vm.expectRevert(bytes(""));
        blackjack.hit{value: 1}(true, 0);
    }

    function testInvalidHandNum() public {
        vm.expectRevert(bytes("Hand invalid"));
        blackjack.hit(false, 1);
    }

    function testHitSuccessful() public {
        blackjack.setPlayerCards(1, 1, 0);
        vm.expectEmit(false, false, false, false);
        emit Hit(1);
        uint8 newCard = blackjack.hit(false, 0);

        emit log_uint(newCard);
    }

    function testHitBust() public {
        // Expect this test to fail 1/13 times because the player will draw an Ace
        blackjack.setPlayerCards(10, 10, 0);
        vm.expectEmit(false, false, false, false);
        emit Bust(1);
        vm.expectEmit(false, false, false, false);
        emit Hit(1);
        blackjack.hit(false, 0);
    }

    function testInvalidTurn() public {
        blackjack.hit(false, 0);
        blackjack.setDealerCard(1);
        emit log_string("Successfully hit");

        vm.expectRevert(bytes(""));
        blackjack.hit(true, 0);
    }

    function testHitSuccessInsuranceTrue() public {
        blackjack.setDealerCard(1);
        blackjack.setPlayerCards(1, 1, 0);
        vm.expectEmit(false, false, false, false);
        emit Hit(1);
        blackjack.hit{value: 1 ether}(true, 0);
    }
}
