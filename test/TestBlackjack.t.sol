// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TestBlackjack.sol";
import "../src/TestBlackjack.sol";

contract ConstructorTest is Test {
    Blackjack public blackjack;
    Dealer public _dealer;

    function setUp() public {
        _dealer = new Dealer();
        vm.deal(address(this), 10 ether);
        blackjack = new Blackjack{value: 1 ether}(
            address(0x0),
            address(_dealer)
        );
        _dealer.transferOwner(address(blackjack));
    }

    function testFailNoValue() public {
        Blackjack blackjack2 = new Blackjack{value: 0}(
            address(0x0),
            address(_dealer)
        );
    }

    function testInitValues() public {
        assertEq(address(blackjack.dealer), address(_dealer));
        assertEq(blackjack.player, address(this));
        assertEq(blackjack.vault, address(0x0));
    }

    function testInitialGameData() public {
        assertEq(blackjack.gameData.betAmount, 1 ether);
        assertEq(blackjack.gameData.insurance, false);
        assertEq(blackjack.gameData.nextOpenHandSlot, 1);
        assertEq(blackjack.gameData.hands[0].firstTurn, true);
    }

    function testInitialHand() public {
        uint hand = uint(
            keccak256(
                abi.encodePacked(
                    block.difficulty,
                    block.timestamp,
                    _dealer.counter
                )
            )
        );
        unchecked {
            uint8 pCardOne = uint8(hand % 13) + 1;
            uint8 dealHand = uint8(((hand / 100) % 13) + 1);
            uint8 pCardTwo = uint8((hand / 10000) % 13) + 1;

            assertEq(blackjack.gameData.dealerHand.cards[0], dealHand);
            assertEq(blackjack.gameData.hands[0].cards[0], pCardOne);
            assertEq(blackjack.gameData.hands[0].cards[1], pCardTwo);
        }
    }
}
