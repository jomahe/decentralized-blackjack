// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    event EtherReceived(uint256);
    mapping(address => bool) authorized;
    address _owner;
    modifier onlyAuthorized() {
        require(authorized[msg.sender], "Not authorized");
        _;
    }

    modifier onlyNewOwner() {
        require(msg.sender == _owner);
        _;
    }

    constructor() {
        _owner = msg.sender;
        authorized[_owner] = true;
    }

    function addAuthorized(address _newAuthorized) external onlyNewOwner {
        authorized[_newAuthorized] = true;
    }

    function payoutFromVault(
        uint256 _amount,
        address _to
    ) external onlyAuthorized nonReentrant {
        (bool sent, ) = payable(_to).call{value: _amount}("");
        require(sent, "Not sent to player");
    }

    receive() external payable {
        emit EtherReceived(msg.value);
    }

    fallback() external payable {
        emit EtherReceived(msg.value);
    }
}
