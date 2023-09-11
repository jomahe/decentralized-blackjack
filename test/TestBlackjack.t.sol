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
        blackjack.setDealerCards(1, 1);
        blackjack.hit{value: 1 ether}(true, 0);
    }

    function testInsuranceTrueNoValue() public {
        blackjack.setDealerCards(1, 1);
        vm.expectRevert(bytes(""));
        blackjack.hit{value: 0}(true, 0);
    }

    function testInsuranceNoAce() public {
        blackjack.setDealerCards(2, 2);
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
        blackjack.setDealerCards(1, 1);
        emit log_string("Successfully hit");

        vm.expectRevert(bytes(""));
        blackjack.hit(true, 0);
    }

    function testHitSuccessInsuranceTrue() public {
        blackjack.setDealerCards(1, 1);
        blackjack.setPlayerCards(1, 1, 0);
        vm.expectEmit(false, false, false, false);
        emit Hit(1);
        blackjack.hit{value: 1 ether}(true, 0);
    }
}

contract StandTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Hit(uint8);
    event Bust(uint8);
    event Win(uint8);
    event Push(uint8);
    event Loss(uint8);
    event PlayerBlackjack();

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            address(0x0),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
    }

    function testPlayerBlackJack() public {
        blackjack.setPlayerCards(1, 10, 0);
        blackjack.setDealerCards(10, 7);
        vm.expectEmit(false, false, false, false);
        emit Win(21);
        vm.expectEmit(false, false, false, false);
        emit PlayerBlackjack();
        blackjack.stand(0);
    }

    function testWinNoBlackjack() public {
        blackjack.setPlayerCards(10, 8, 0);
        blackjack.setDealerCards(10, 7);
        vm.expectEmit(false, false, false, false);
        emit Win(18);
        blackjack.stand(0);
    }

    function testPush() public {
        blackjack.setPlayerCards(10, 7, 0);
        blackjack.setDealerCards(10, 7);
        vm.expectEmit(false, false, false, false);
        emit Push(17);
        blackjack.stand(0);
    }

    function testLoss() public {
        blackjack.setPlayerCards(10, 7, 0);
        blackjack.setDealerCards(10, 1);
        vm.expectEmit(false, false, false, false);
        emit Loss(17);
        blackjack.stand(0);
    }
}

contract SplitTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Split(uint8);

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            address(0x0),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        blackjack.setPlayerCards(8, 8, 0);
    }

    function testSplitNoPair() public {
        blackjack.setPlayerCards(1, 2, 0);
        vm.expectRevert(bytes("Need a pair in hand"));
        blackjack.split{value: 1 ether}(0);
    }

    function testSplitNoValue() public {
        vm.expectRevert(bytes("Need to match original bet"));
        blackjack.split{value: 0}(0);
    }

    function testSplitSuccessful() public {
        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(0);

        Blackjack.Hand[4] memory hands = blackjack.getHands();
        // Hands 0,1 should have two cards and 2,3 should have zero.
        assert(
            hands[0].cards.length == hands[1].cards.length &&
                hands[2].cards.length == hands[3].cards.length &&
                hands[0].cards.length != hands[2].cards.length
        );
    }

    function testSplitTwiceUnsuccessful() public {
        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(0);
        blackjack.setPlayerCards(8, 9, 1);

        vm.expectRevert(bytes("Need a pair in hand"));
        blackjack.split(1);
    }

    function testSplitTwiceSuccessful() public {
        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(0);

        blackjack.setPlayerCards(8, 8, 1);

        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(1);

        Blackjack.Hand[4] memory hands = blackjack.getHands();
        // Hands 0,1,2 should have two cards and 2,3 should have zero.
        assert(
            hands[0].cards.length == hands[1].cards.length &&
                hands[1].cards.length == hands[2].cards.length &&
                hands[2].cards.length != hands[3].cards.length
        );
    }

    function testSplitThriceSuccessful() public {
        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(0);

        blackjack.setPlayerCards(8, 8, 1);

        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(1);

        blackjack.setPlayerCards(8, 8, 2);

        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(2);

        Blackjack.Hand[4] memory hands = blackjack.getHands();
        // Hands 0,1,2 should have two cards and 2,3 should have zero.
        assert(
            hands[0].cards.length == hands[1].cards.length &&
                hands[1].cards.length == hands[2].cards.length &&
                hands[2].cards.length == hands[3].cards.length
        );
    }

    function testCantSplitFourTimes() public {
        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(0);

        blackjack.setPlayerCards(8, 8, 1);

        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(1);

        blackjack.setPlayerCards(8, 8, 2);

        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(2);

        blackjack.setPlayerCards(8, 8, 3);

        vm.expectRevert(bytes("Can only split to four hands"));
        blackjack.split{value: 1 ether}(3);
    }

    function testHandComposition() public {
        vm.expectEmit(false, false, false, false);
        emit Split(8);
        blackjack.split{value: 1 ether}(0);

        uint8[] memory hand0 = blackjack.getCardsFromHand(0);
        uint8[] memory hand1 = blackjack.getCardsFromHand(1);
        require(hand0[0] == hand1[0], "split cards don't match");

        require(
            hand0[1] != hand1[0] || hand0[0] != hand1[1],
            "Something fishy here..."
        );
    }
}
