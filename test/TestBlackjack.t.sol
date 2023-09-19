// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Blackjack} from "../src/TestBlackjack.sol";
import {Dealer} from "../src/TestDealer.sol";
import {Vault} from "../src/TestVault.sol";

contract ConstructorTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;
    Vault public vault;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            payable(address(vault)),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        vault.addAuthorized(address(blackjack));

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
            payable(address(vault)),
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
    Vault public vault;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Hit(uint8);
    event Bust(uint8);

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            payable(address(vault)),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        vault.addAuthorized(address(blackjack));
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

    receive() external payable {}
}

contract StandTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;
    Vault public vault;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Hit(uint8);
    event Bust(uint8);
    event Win(uint8);
    event Push(uint8);
    event Loss(uint8);
    event Paid(uint256);
    event PlayerBlackjack();

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            payable(address(vault)),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        vault.addAuthorized(address(blackjack));
    }

    function testPlayerBlackJack() public {
        blackjack.setPlayerCards(1, 10, 0);
        blackjack.setDealerCards(10, 7);
        vm.expectEmit(false, false, false, false);
        emit Win(21);
        vm.expectEmit(false, false, false, false);
        emit Paid(1);
        vm.expectEmit(false, false, false, false);
        emit PlayerBlackjack();
        blackjack.stand(false, 0);
    }

    function testWinNoBlackjack() public {
        blackjack.setPlayerCards(10, 8, 0);
        blackjack.setDealerCards(10, 7);
        vm.expectEmit(false, false, false, false);
        emit Win(18);
        blackjack.stand(false, 0);
    }

    function testPush() public {
        blackjack.setPlayerCards(10, 7, 0);
        blackjack.setDealerCards(10, 7);
        vm.expectEmit(false, false, false, false);
        emit Push(17);
        blackjack.stand(false, 0);
    }

    function testLoss() public {
        blackjack.setPlayerCards(10, 7, 0);
        blackjack.setDealerCards(10, 1);
        vm.expectEmit(false, false, false, false);
        emit Loss(17);
        blackjack.stand(false, 0);
    }

    receive() external payable {}
}

contract SplitTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;
    Vault public vault;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Split(uint8);

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            payable(address(vault)),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        vault.addAuthorized(address(blackjack));
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

contract HandSumTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;
    Vault public vault;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Split(uint8);

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            payable(address(vault)),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        vault.addAuthorized(address(blackjack));
        blackjack.setPlayerCards(8, 8, 0);
    }

    function testAces() public {
        blackjack.setPlayerCards(1, 1, 0);
        uint8[] memory aces = new uint8[](5);
        aces[0] = 1;
        aces[1] = 1;
        aces[2] = 1;
        aces[3] = 1;
        aces[4] = 1;
        blackjack.addPlayerCards(aces, 0);

        assertEq(blackjack.getHandSum(0, false), 17);
    }

    function testSoftSeventeen() public {
        blackjack.setPlayerCards(1, 6, 0);
        assertEq(blackjack.getHandSum(0, false), 17);
    }

    function testHardSeventeen() public {
        blackjack.setPlayerCards(10, 5, 0);
        uint8[] memory aces = new uint8[](2);
        aces[0] = 1;
        aces[1] = 1;
        blackjack.addPlayerCards(aces, 0);

        assertEq(blackjack.getHandSum(0, false), 17);
    }
}

contract PayoutTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;
    Vault public vault;

    uint8[2] playerCards;
    uint8[2] dealerCards;
    Blackjack.Hand playerHand;
    Blackjack.Hand dealerHand;

    event Win(uint8);
    event Loss(uint8);
    event Push(uint8);
    event EtherReceived(uint256);
    event Paid(uint256);

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            payable(address(vault)),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
        vault.addAuthorized(address(blackjack));
    }

    function testWinPayoutNormal() public {
        blackjack.setDealerCards(10, 7);
        blackjack.setPlayerCards(10, 8, 0);

        vm.expectEmit(false, false, false, false);
        emit Paid(1 ether);
        blackjack.stand(false, 0);

        assertEq(address(vault).balance, 9 ether);
    }

    function testWinPayoutBlackjack() public {
        blackjack.setDealerCards(10, 7);
        blackjack.setPlayerCards(10, 1, 0);

        vm.expectEmit(false, false, false, false);
        emit Paid(1.5 ether);
        blackjack.stand(false, 0);

        assertEq(address(vault).balance, 8.5 ether);
    }

    function testLoss() public {
        blackjack.setDealerCards(10, 7);
        blackjack.setPlayerCards(10, 2, 0);
        blackjack.stand(false, 0);

        assertEq(address(vault).balance, 11 ether);
    }

    function testMultipleHands() public {
        blackjack.setDealerCards(10, 7);
        blackjack.setPlayerCards(9, 9, 0);

        blackjack.split{value: 1 ether}(0);

        blackjack.setPlayerCards(9, 9, 0);
        blackjack.setPlayerCards(9, 9, 1);

        blackjack.split{value: 1 ether}(0);
        blackjack.split{value: 1 ether}(1);

        blackjack.setPlayerCards(9, 9, 0);
        blackjack.setPlayerCards(9, 8, 1);
        blackjack.setPlayerCards(9, 7, 2);
        blackjack.setPlayerCards(10, 1, 3);

        vm.expectEmit(false, false, false, false);
        emit Win(1);
        vm.expectEmit(false, false, false, false);
        emit Paid(1 ether);
        vm.expectEmit(false, false, false, false);
        emit EtherReceived(1 ether);
        blackjack.stand(false, 0);
        // require(address(vault).balance == 9 ether, "Balance incorrect");
        assertEq(address(vault).balance, 9 ether);

        vm.expectEmit(false, false, false, false);
        emit Push(1);
        blackjack.stand(false, 1);
        assertEq(address(vault).balance, 9 ether);

        vm.expectEmit(false, false, false, false);
        emit Loss(1);
        vm.expectEmit(false, false, false, false);
        emit EtherReceived(1 ether);
        blackjack.stand(false, 2);
        assertEq(address(vault).balance, 10 ether);

        vm.expectEmit(false, false, false, false);
        emit Win(1);
        vm.expectEmit(false, false, false, false);
        emit Paid(1 ether);
        blackjack.stand(false, 3);
        assertEq(address(vault).balance, 8.5 ether);
    }

    receive() external payable {}
}
