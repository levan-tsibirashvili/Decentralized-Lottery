// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

pragma solidity ^0.8.35;

contract Lottery is VRFConsumerBaseV2Plus {

    error priceShouldBeMoreThenZero();
    error incorrectDuration();
    error lotteryShouldStartInFuture();
    error phaseDoesNotExist();
    error incorrectTicketPrice(uint256 ticketPrice);
    error phaseIsOver();
    error phaseDidnotStartedYet(uint256 startTime);
    error phaseAlredyFinished(uint256 endTime);
    error soldTicketShouldBeMoreThen1();
    error phaseDidNotFinished(uint256 endTime);
    error phaseIsNotOverYet();
    error TransferFailed();
    error notEnoughtFunds();
    error UserDontHaveAnyTicket();
    error cannotRefundInActivePhase();

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

    /// PhaseID => lotteryPhase
    mapping(uint256 => lotteryPhase) public lotteryPhases;

    /// requestId => phaseId
    mapping(uint256 => uint256) public requestToPhase;

    /// PhaseID => TicketID => OwnerAddress
    mapping(uint256 => mapping(uint256 => address)) public ticketOwner;

    /// PhaseID => winnerAddress
    mapping(uint256 => address) public phaseWinner;

    /// PhaseID => TicketID
    mapping(uint256 => uint256[]) public ticketsInPhase;

    /// OwnerAddress => PhaseID => TicketQuantity
    mapping(address => mapping(uint256 => uint256)) public refundableAmount;

    struct lotteryPhase {
        uint256 ticketPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 fee;
        bool isActive;
        uint256 jeckpot;
        uint256 soldTicketAmount;
    }

    event LotteryPhaseCreated(uint256 indexed _phaseId, uint256 indexed ticketPrice, uint256 indexed startTime, uint256 endTime, uint256 fee);
    event soldTicket(uint256 indexed _phaseId, uint256 indexed _ticketId, address indexed _owner, uint256 _pricePaid);
    event transferFailed(uint256 indexed _phaseId, uint256 indexed _ticketID, address indexed _ticketOwner, uint256 _price);
    event successTransfer(address indexed _reciever, uint256 _amount );


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

        emit LotteryPhaseCreated(lastLotteryPhaseId, _ticketPrice, _startTime, _endTime, _fee);
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
        ticketOwner[_phaseId][ticketID] = msg.sender;
        ticketsInPhase[_phaseId].push(ticketID);
        refundableAmount[msg.sender][_phaseId] += 1;

        if(targLotPhase.fee > 0){
            uint256 feeAmount = (msg.value * targLotPhase.fee) / 100;
            targLotPhase.jeckpot += msg.value - feeAmount;
        }

        if (targLotPhase.fee == 0){
            targLotPhase.jeckpot += msg.value;
        }

        emit soldTicket(_phaseId, ticketID, msg.sender, msg.value);
    }

    function stopPhase(uint256 _phaseId) external onlyOwner(){
        if(_phaseId > lastLotteryPhaseId) revert phaseDoesNotExist();

        lotteryPhases[_phaseId].isActive = false;
    }

    function withdrawRefund(uint256 _phaseId) external {
        lotteryPhase storage targPhase = lotteryPhases[_phaseId];
        uint256 userTickets = refundableAmount[msg.sender][_phaseId];
        uint256 refundPrice = targPhase.ticketPrice * userTickets;

        if(targPhase.isActive == true) revert cannotRefundInActivePhase();
        if(userTickets == 0) revert UserDontHaveAnyTicket();

        refundableAmount[msg.sender][_phaseId] = 0;
        targPhase.jeckpot -= refundPrice;
        targPhase.soldTicketAmount -= userTickets;

        (bool success, ) = msg.sender.call{value: refundPrice} ("");
        if(!success) revert TransferFailed();

        emit successTransfer(msg.sender, refundPrice);
    }

    function sendFund(address _to, uint256 _amount) external onlyOwner(){
        if(_amount > address(this).balance) revert notEnoughtFunds();

        (bool success,) = _to.call{value: _amount}("");
        if(!success) revert TransferFailed();

        emit successTransfer(_to, _amount);
    }

    function drawWinner(uint256 _phaseId) public onlyOwner(){
        if(lotteryPhases[_phaseId].isActive == true) revert phaseIsNotOverYet();
        if(lotteryPhases[_phaseId].soldTicketAmount <= 1) revert soldTicketShouldBeMoreThen1();
        if(block.timestamp < lotteryPhases[_phaseId].endTime) revert phaseDidNotFinished(lotteryPhases[_phaseId].endTime);

        // 3. Chainlink-თან მოთხოვნის გაგზავნა
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: 200000, // გაზის ლიმიტი პასუხის მისაღებად (200k საკმარისია)
                numWords: 1, // ვითხოვთ 1 რიცხვს
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true}) // ვიხდით ETH-ით (ან ქსელის ვალუტით)
                )
            })
        );

        // 4. მოთხოვნის ID-ის მიბმა ფაზის ID-სთან
        requestToPhase[requestId] = _phaseId;

        // 5. უსაფრთხოებისთვის ფაზის დახურვა, რათა ლოდინის რეჟიმში ბილეთები აღარ იყიდონ
        lotteryPhases[_phaseId].isActive = false;
    }

    /**
     * @dev ეს ფუნქცია ავტომატურად გამოიძახება Chainlink-ის მიერ, 
     * როდესაც შემთხვევითი რიცხვი მზად იქნება.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // 1. ვიღებთ შემთხვევით რიცხვს
        uint256 randomWord = randomWords[0];

        // 2. ვადგენთ, რომელ ფაზას ეკუთვნის ეს პასუხი
        uint256 phaseId = requestToPhase[requestId];

        // 3. ვიღებთ კონკრეტული ფაზის მონაცემებს
        lotteryPhase storage targLotPhase = lotteryPhases[phaseId];

        // 4. ვაკეთებთ ნაშთიან გაყოფას გაყიდული ბილეთების რაოდენობაზე
        uint256 winningTicketId = randomWord % targLotPhase.soldTicketAmount;

        // 5. ვპოულობთ გამარჯვებულის მისამართს ახალი მაპინგიდან
        address winner = ticketOwner[phaseId][winningTicketId];

        phaseWinner[phaseId] = winner;

        uint256 amountToTransfer = targLotPhase.jeckpot;
        targLotPhase.jeckpot = 0;
        targLotPhase.isActive = false;

        (bool success, ) = payable(winner).call{value: amountToTransfer}("");
        if(!success) revert("Transfer failed");
    }

}