// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.7;

// import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

// contract Dealer is VRFConsumerBaseV2 {
//     event RequestSent(uint256 requestId, uint32 numWords);
//     event RequestFulfilled(uint256 requestId, uint256[] randomWords);

//     struct RequestStatus {
//         bool fulfilled;
//         bool exists;
//         uint256[] randomWords;
//     }
//     mapping(uint256 => RequestStatus) public requests;
//     VRFCoordinatorV2Interface coordinator;
//     uint64 subscriptionId;
//     uint256[] public requestIds;
//     uint256 public lastRequestId;
//     bytes32 keyHash =
//         0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
//     uint32 callbackGasLimit = 100000;
//     uint16 requestConfirmations = 3;
//     uint32 numWords = 1;
//     address owner;

//     modifier onlyOwner() {
//         require(msg.sender == owner);
//         _;
//     }

//     function setOwner(address _newOwner) external onlyOwner {
//         owner = _newOwner;
//     }

//     /**
//      * HARDCODED FOR SEPOLIA
//      * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
//      */
//     constructor(
//         uint64 _subscriptionId
//     ) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) {
//         coordinator = VRFCoordinatorV2Interface(
//             0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
//         );
//         subscriptionId = _subscriptionId;
//         owner = msg.sender;
//     }

//     // Assumes the subscription is funded sufficiently.
//     function requestRandomWords()
//         external
//         onlyOwner
//         returns (uint256 requestId)
//     {
//         // Will revert if subscription is not set and funded.
//         requestId = coordinator.requestRandomWords(
//             keyHash,
//             subscriptionId,
//             requestConfirmations,
//             callbackGasLimit,
//             numWords
//         );
//         requests[requestId] = RequestStatus({
//             randomWords: new uint256[](0),
//             exists: true,
//             fulfilled: false
//         });
//         requestIds.push(requestId);
//         lastRequestId = requestId;
//         emit RequestSent(requestId, numWords);
//         return requestId;
//     }

//     function fulfillRandomWords(
//         uint256 _requestId,
//         uint256[] memory _randomWords
//     ) internal override {
//         require(requests[_requestId].exists, "request not found");
//         requests[_requestId].fulfilled = true;
//         requests[_requestId].randomWords = _randomWords;
//         emit RequestFulfilled(_requestId, _randomWords);
//     }

//     function getRequestStatus(
//         uint256 _requestId
//     ) external view returns (bool fulfilled, uint256[] memory randomWords) {
//         require(requests[_requestId].exists, "request not found");
//         RequestStatus memory request = requests[_requestId];
//         return (request.fulfilled, request.randomWords);
//     }
// }
