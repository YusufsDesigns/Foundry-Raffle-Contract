// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 public constant SEND_VALUE = 0.2 ether;
    uint256 public constant INTERVAL = 30;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    address vrfCoordinator;

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = config.vrfCoordinator;
    }

    /* Raffle Tests */
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnouph() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordesPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEntered {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
    }

    /* CheckUpKeep Tests */
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnouphTimeHasNotPassed() public {
        vm.warp(block.timestamp + INTERVAL - 10);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public raffleEntered {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    /* PerformUpKeep Tests */
    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public raffleEntered {
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfChechUpKeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
        currentBalance = currentBalance + SEND_VALUE;
        numPlayers = 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /* FulfillRandomWords Tests */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerAndResetsAndSendsMoney() public raffleEntered {
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: SEND_VALUE}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingLastTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = SEND_VALUE * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingLastTimeStamp > startingTimeStamp);
    }
}