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
        VOTES_TALLIED
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

    // immutable variables
    address private immutable i_administrator;

    // state variables
    address[] public s_participants;
    WorkflowStatus s_votingStatus;
    Proposal[] public s_proposals;
    Voter[] public s_voters;

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

    constructor() Ownable(msg.sender) {
        i_administrator = msg.sender;
        s_votingStatus = WorkflowStatus.REGISTERING_VOTERS;
    }

    function getVotingStatus() public view returns (WorkflowStatus) {
        return s_votingStatus;
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

    function createProposal(string calldata description) public {
        if (s_votingStatus != WorkflowStatus.PROPOSALS_REGISTRATION_STARTED) {
            revert Voting__ProposalRegistrationNotOpen();
        }

        if (!checkSenderIsParticipant()) {
            revert Voting__NotParticipant();
        }

        s_proposals.push(Proposal({description: description, voteCount: 0}));

        emit ProposalRegistered(s_proposals.length - 1);
    }

    function createVote(uint256 proposalID) public {
        if (s_votingStatus != WorkflowStatus.VOTING_SESSION_STARTED) {
            revert Voting__VotingSessionClosed();
        }

        if (!checkSenderIsParticipant()) {
            revert Voting__NotParticipant();
        }

        s_voters.push(
            Voter({
                isRegistered: true,
                hasVoted: true,
                votedProposalID: proposalID
            })
        );

        emit Voted(msg.sender, proposalID);
    }
}
