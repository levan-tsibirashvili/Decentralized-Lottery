// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

pragma solidity ^0.8.35;

contract Lottery is VRFConsumerBaseV2Plus {

    // State ცვლადები Chainlink-ისთვის
    uint256 public s_subscriptionId;
    bytes32 public keyHash;

    // კონსტრუქტორში აუცილებელია Coordinator-ის მისამართის გადაცემა მშობელი კონტრაქტისთვის
    constructor(
        uint256 subscriptionId,
        address vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_subscriptionId = subscriptionId;
        keyHash = _keyHash;
    }

    uint256 public lastLotteryPhaseId;

    /// PhaseID => tottalPlayers
    mapping(uint256 => uint256) public tottalPlayersInPhase;

    /// player => PhaseID => userTickets
    mapping(address => mapping(uint256 => uint256[])) palyerTickets;

    /// PhaseID => winners
    mapping(uint256 => address[]) public phaseWinner;

    /// PhaseID => lotteryPhase
    mapping(uint256 => lotteryPhase) public lotteryPhases;

    struct lotteryPhase {
        uint256 ticketPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 fee;
        bool isActive;
        uint256 jeckpot;
        uint256 soldTicketAmount;
    }

    event LotteryPhaseCreated(uint256 ticketPrice, uint256 startTime, uint256 endTime, uint256 fee);

    function createLotteryPhase(uint256 _ticketPrice, uint256 _startTime, uint256 _endTime, uint256 _fee) external onlyOwner(){
        if(_ticketPrice == 0) revert priceShouldBeMoreThenZero();
        if(_startTime + 24 hours >= _endTime) revert incorrectDuration();
        if(_startTime < block.timestamp) revert lotteryShouldStartInFuture();

        lastLotteryPhaseId ++;

        lotteryPhases[lastLotteryPhaseId] = lotteryPhase ({
            ticketPrice: _ticketPrice,
            startTime: _startTime,
            endTime: _endTime,
            fee: _fee,
            isActive: true,
            jeckpot: 0,
            soldTicketAmount: 0
        }) ;

        emit LotteryPhaseCreated(_ticketPrice, _startTime, _endTime, _fee);
    }

    function stopPhase(uint256 _phaseId) external onlyOwner(){
        if(_phaseId > lastLotteryPhaseId) revert phaseDoesNotExist();

        lotteryPhases[_phaseId].isActive = false;
    }

    function buyTicket(uint256 _phaseId) external payable {
        lotteryPhase storage targLotPhase = lotteryPhases[_phaseId];

        if(targLotPhase.isActive == false) revert phaseIsOver();
        if(block.timestamp < targLotPhase.startTime) revert phaseDidnotStartedYet(targLotPhase.startTime);
        if(block.timestamp > targLotPhase.endTime) revert phaseAlredyFinished(targLotPhase.endTime);
        if(msg.value != targLotPhase.ticketPrice) revert incorrectTicketPrice(targLotPhase.ticketPrice);

        uint256 ticketID = targLotPhase.soldTicketAmount;

        targLotPhase.soldTicketAmount ++;
        palyerTickets[msg.sender][_phaseId].push(ticketID);
        tottalPlayersInPhase[_phaseId] ++;

        if(targLotPhase.fee > 0){
            targLotPhase.jeckpot += msg.value * targLotPhase.fee / 100;
        }else if (targLotPhase.fee == 0){
            targLotPhase.jeckpot += msg.value;
        }

    }




    /**
     * @dev ეს ფუნქცია ავტომატურად გამოიძახება Chainlink-ის მიერ, 
     * როდესაც შემთხვევითი რიცხვი მზად იქნება.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // 1. ვიღებთ ჩვენს შემთხვევით რიცხვს მასივის ნულოვანი ინდექსიდან
        uint256 randomWord = randomWords[0];
        
        // 2. აქ უნდა გააგრძელოთ გამარჯვებულის გამოვლენის ლოგიკა
        // დროებით შეგიძლიათ უბრალოდ დატოვოთ ცარიელი ან შეინახოთ State ცვლადში ტესტირებისთვის
    }





    error priceShouldBeMoreThenZero();
    error incorrectDuration();
    error lotteryShouldStartInFuture();
    error phaseDoesNotExist();
    error incorrectTicketPrice(uint256 ticketPrice);
    error phaseIsOver();
    error phaseDidnotStartedYet(uint256 startTime);
    error phaseAlredyFinished(uint256 endTime);


}