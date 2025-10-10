// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Ownable} from "./openzepplin/Ownable.sol";

/*
  Contract elements should be laid out in the following order:
    1. Pragma statements
    2. Import statements
    3. Events
    4. Errors
    5. Interfaces
    6. Libraries
    7. Contracts

  Inside each contract, library or interface, use the following order:
    1. Type declarations
    2. State variables
    3. Events
    4. Errors
    5. Modifiers
    6. Functions 
*/

contract Voting is Ownable {
    enum WorkflowStatus {
        REGISTERING_VOTERS,
        PROPOSALS_REGISTRATION_STARTED,
        PROPOSALS_REGISTRATION_ENDED,
        VOTING_SESSION_STARTED,
        VOTING_SESSION_ENDED,
        VOTES_TALLIED,
        CLOSED_SESSION
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalID;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    // state variables
    address[] private s_participants;
    WorkflowStatus s_votingStatus;
    Voter[] private s_voters;
    uint256 private s_numberOfProposals;
    uint256 private s_winningProposalID;

    mapping(uint256 => Proposal) private s_proposalIDToProposal;
    mapping(address => Voter) private s_participantToVote;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint proposalID);
    event Voted(address voter, uint proposalId);

    error Voting__VoterRegisterNotOpen();
    error Voting__NotAdministrator();
    error Voting__ProposalRegistrationNotOpen();
    error Voting__NotParticipant();
    error Voting__VotingSessionClosed();
    error Voting__ProposalNotFound();
    error Voting__ParticipantHasAlreadyVote();
    error Voting__WinnerNotPicked();
    error Voting__NoWinningProposal();
    error Voting__ParticipantIndexOutOfRange();
    error Voting__VoteIndexOutOfRange();
    error Voting__NoParticipant();
    error Voting__NoVoters();

    constructor() Ownable(msg.sender) {
        s_votingStatus = WorkflowStatus.REGISTERING_VOTERS;
        s_numberOfProposals = 0;
    }

    function getVotingStatus() public view returns (WorkflowStatus) {
        return s_votingStatus;
    }

    function getNumberOfProposals() public view returns (uint256) {
        return s_numberOfProposals;
    }

    function getWinner() public view returns (Proposal memory winningProposal) {
        if (
            s_votingStatus != WorkflowStatus.VOTES_TALLIED &&
            s_votingStatus != WorkflowStatus.CLOSED_SESSION
        ) {
            revert Voting__WinnerNotPicked();
        }

        if (s_winningProposalID == 0) {
            revert Voting__NoWinningProposal();
        }

        return s_proposalIDToProposal[s_winningProposalID];
    }

    function getProposal(
        uint256 proposalID
    ) public view returns (Proposal memory proposal) {
        if (proposalID < 1 || proposalID > s_numberOfProposals) {
            revert Voting__ProposalNotFound();
        }

        return s_proposalIDToProposal[proposalID];
    }

    function getNumberofParticipants() public view returns (uint256) {
        return s_participants.length;
    }

    function getParticipant(
        uint256 participantIndex
    ) public view returns (address participant) {
        if (s_participants.length == 0) {
            revert Voting__NoParticipant();
        }

        if (participantIndex > s_participants.length) {
            revert Voting__ParticipantIndexOutOfRange();
        }

        return s_participants[participantIndex];
    }

    function getVote(
        uint256 voteIndex
    ) public view returns (Voter memory vote) {
        if (s_voters.length == 0) {
            revert Voting__NoVoters();
        }
        if (voteIndex > s_voters.length) {
            revert Voting__VoteIndexOutOfRange();
        }

        return s_voters[voteIndex];
    }

    function checkSenderIsParticipant() private view returns (bool) {
        if (s_participants.length == 0) {
            return false;
        }

        for (uint256 i = 0; i < s_participants.length; i++) {
            if (msg.sender == s_participants[i]) {
                return true;
            }
        }

        return false;
    }

    function registerVoter() external {
        if (s_votingStatus != WorkflowStatus.REGISTERING_VOTERS) {
            revert Voting__VoterRegisterNotOpen();
        }

        s_participants.push(msg.sender);
        emit VoterRegistered(msg.sender);
    }

    function startProposalRegistration() public {
        _checkOwner();
        WorkflowStatus oldWorkflowStatus = s_votingStatus;
        s_votingStatus = WorkflowStatus.PROPOSALS_REGISTRATION_STARTED;

        emit WorkflowStatusChange(oldWorkflowStatus, s_votingStatus);
    }

    function endProposalRegistration() public {
        _checkOwner();
        WorkflowStatus oldWorkflowStatus = s_votingStatus;
        s_votingStatus = WorkflowStatus.PROPOSALS_REGISTRATION_ENDED;

        emit WorkflowStatusChange(oldWorkflowStatus, s_votingStatus);
    }

    function startVotingSession() public {
        _checkOwner();
        WorkflowStatus oldWorkflowStatus = s_votingStatus;
        s_votingStatus = WorkflowStatus.VOTING_SESSION_STARTED;

        emit WorkflowStatusChange(oldWorkflowStatus, s_votingStatus);
    }

    function endVotingSession() public {
        _checkOwner();
        WorkflowStatus oldWorkflowStatus = s_votingStatus;
        // TODO: add check on old work flow status to be sure we were voting
        s_votingStatus = WorkflowStatus.VOTING_SESSION_ENDED;

        emit WorkflowStatusChange(oldWorkflowStatus, s_votingStatus);
    }

    function startTallying() private {
        _checkOwner();
        WorkflowStatus oldWorkflowStatus = s_votingStatus;
        s_votingStatus = WorkflowStatus.VOTES_TALLIED;

        emit WorkflowStatusChange(oldWorkflowStatus, s_votingStatus);
    }

    function endSession() private {
        _checkOwner();

        WorkflowStatus oldWorkflowStatus = s_votingStatus;
        s_votingStatus = WorkflowStatus.CLOSED_SESSION;

        emit WorkflowStatusChange(oldWorkflowStatus, s_votingStatus);
    }

    function createProposal(string calldata description) public {
        if (s_votingStatus != WorkflowStatus.PROPOSALS_REGISTRATION_STARTED) {
            revert Voting__ProposalRegistrationNotOpen();
        }

        if (!checkSenderIsParticipant()) {
            revert Voting__NotParticipant();
        }

        s_numberOfProposals++;

        s_proposalIDToProposal[s_numberOfProposals] = Proposal({
            description: description,
            voteCount: 0
        });

        emit ProposalRegistered(s_numberOfProposals);
    }

    function createVote(uint256 proposalID) public {
        if (s_votingStatus != WorkflowStatus.VOTING_SESSION_STARTED) {
            revert Voting__VotingSessionClosed();
        }

        if (!checkSenderIsParticipant()) {
            revert Voting__NotParticipant();
        }

        if (proposalID > s_numberOfProposals) {
            revert Voting__ProposalNotFound();
        }

        Voter memory existingVote = s_participantToVote[msg.sender];
        if (existingVote.hasVoted) {
            revert Voting__ParticipantHasAlreadyVote();
        }

        s_proposalIDToProposal[proposalID].voteCount += 1;

        Voter memory vote = Voter({
            isRegistered: true,
            hasVoted: true,
            votedProposalID: proposalID
        });

        s_voters.push(vote);
        s_participantToVote[msg.sender] = vote;

        emit Voted(msg.sender, proposalID);
    }

    function pickWiningProposalAndCloseSession() public {
        _checkOwner();

        startTallying();

        uint256 winningProposalID = 0;
        uint256 maxVotesCounts = 0;

        for (uint256 i = 1; i <= s_numberOfProposals; i++) {
            if (s_proposalIDToProposal[i].voteCount > maxVotesCounts) {
                winningProposalID = i;
                maxVotesCounts = s_proposalIDToProposal[i].voteCount;
            }
        }

        s_winningProposalID = winningProposalID;

        endSession();
    }
}
