// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// შემოგვაქვს Chainlink-ის ოფიციალური Mock კონტრაქტი
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Lottery} from "./Lottery.sol";

contract LotteryDeployer {
    VRFCoordinatorV2_5Mock public vrfMock;
    Lottery public lotteryContract;
    uint256 public subscriptionId;

    constructor() {
        // 1. Mock მარშრუტიზატორის დეპლოი (გადაეცემა საბაზისო საკომისიოების იმიტირებული პარამეტრები)
        vrfMock = new VRFCoordinatorV2_5Mock(100000000000000000, 1000000000, 4000000000000000);

        // 2. Subscription-ის (ბილინგის ანგარიშის) შექმნა
        subscriptionId = vrfMock.createSubscription();

        // 3. ანგარიშის შევსება იმიტირებული ფონდებით ტესტირებისთვის
        vrfMock.fundSubscription(subscriptionId, 10 ether);

        // 4. იმიტირებული Gas Lane იდენტიფიკატორი
        bytes32 testKeyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

        // 5. თქვენი Lottery კონტრაქტის დეპლოი ავტომატურად გენერირებული პარამეტრებით
        lotteryContract = new Lottery(
            subscriptionId,
            address(vrfMock),
            testKeyHash
        );

        // 6. თქვენი კონტრაქტის დამატება Subscription-ზე, რათა მიეცეს მოთხოვნის გაგზავნის უფლება
        vrfMock.addConsumer(subscriptionId, address(lotteryContract));

        // 7. მფლობელობის გადაცემა ინიციატორზე (თქვენს Remix ანგარიშზე)
        lotteryContract.transferOwnership(msg.sender);
    }
}