// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions



// SPDX-License-Identifier: MIT


pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle contract
 * @author Mccarthy michael
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__SendMoreToENterRaffle();
    error NotEnoughTime();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable [] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address private i_link;
    address private  i_account;

    RaffleState private s_raffleState;



   

    event RaffleEntered(address indexed player);
    event  WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32
    gasLane, uint256 subscriptionID, uint32 callBack , address link, address account  )
     VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        // s_vrfCoordinator.requestRandomWords();
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionID;
        i_callbackGasLimit = callBack;

        s_raffleState = RaffleState.OPEN;
        i_link = link;
        i_account = account;
        



    }
    function enterRaffle () public payable{
        if (msg.value <  i_entranceFee ) {
            revert  Raffle__SendMoreToENterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // when should the winner be picked?
    /**
     * @dev this is the function that the chainlinkk nodes will call
     * to see if the lottery is ready to have a winner picked.
     * The following should be true in  order for unkeepNeeded to be true:
     * 1. the time interval has passed between raffle runs
     * 2. the lottery is open
     * 3. the contract has eth 
     * 4. implicity, your subscription has link
     * @param - ignored  
     * @return upkeepNeeded - true if its time the lottery
     * @return 
     */

    function checkUpkeep(bytes memory /* checkData */)
     public 
     view  
     returns (bool upkeepNeeded, bytes memory /* performData */) {
         bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
         bool isOpen = s_raffleState == RaffleState.OPEN;
         bool hasEth = address(this).balance > 0;
         bool hasPlayers = s_players.length > 0;

         upkeepNeeded = timeHasPassed && isOpen && hasEth && hasPlayers; 
         return (upkeepNeeded, "");
         
       
    }

    function performUpkeep(bytes calldata /* performData */)  external {
       (bool upkeepNeeded,) = checkUpkeep("");
       if (!upkeepNeeded) {
        revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
       }
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
             });

       uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
       emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId*/ , uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert();
        }
        emit WinnerPicked(s_recentWinner);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;

    }
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayersRecorded(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address) {
        return s_recentWinner;
    }

    function getGasLane() external view returns(bytes32) {
        return i_keyHash;
    }

}