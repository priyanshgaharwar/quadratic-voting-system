// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Quadratic Voting System
 * @dev A smart contract implementing quadratic voting mechanism
 * @author Quadratic Voting Team
 */
contract QuadraticVotingSystem {
    
    // Structs
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 totalVotes;
        uint256 totalCreditsUsed;
        uint256 deadline;
        bool active;
        address proposer;
        mapping(address => uint256) voterCredits;
        mapping(address => uint256) voterVotes;
    }
    
    struct Voter {
        bool isRegistered;
        uint256 totalCredits;
        uint256 availableCredits;
        uint256 participatedProposals;
    }
    
    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    
    uint256 public proposalCount;
    uint256 public constant INITIAL_CREDITS = 100;
    uint256 public constant MIN_PROPOSAL_DURATION = 1 days;
    uint256 public constant MAX_PROPOSAL_DURATION = 30 days;
    
    address public admin;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 votes, uint256 creditsUsed);
    event VoterRegistered(address indexed voter, uint256 credits);
    event ProposalEnded(uint256 indexed proposalId, uint256 totalVotes);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(proposals[_proposalId].active, "Proposal not active");
        require(block.timestamp <= proposals[_proposalId].deadline, "Proposal deadline passed");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        proposalCount = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new voter with initial credits
     * @param _voter Address of the voter to register
     */
    function registerVoter(address _voter) external onlyAdmin {
        require(!voters[_voter].isRegistered, "Voter already registered");
        require(_voter != address(0), "Invalid voter address");
        
        voters[_voter] = Voter({
            isRegistered: true,
            totalCredits: INITIAL_CREDITS,
            availableCredits: INITIAL_CREDITS,
            participatedProposals: 0
        });
        
        emit VoterRegistered(_voter, INITIAL_CREDITS);
    }
    
    /**
     * @dev Core Function 2: Create a new proposal for voting
     * @param _title Title of the proposal
     * @param _description Description of the proposal
     * @param _duration Duration of the proposal in seconds
     */
    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _duration
    ) external onlyRegisteredVoter {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_duration >= MIN_PROPOSAL_DURATION && _duration <= MAX_PROPOSAL_DURATION, 
                "Invalid proposal duration");
        
        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.totalVotes = 0;
        newProposal.totalCreditsUsed = 0;
        newProposal.deadline = block.timestamp + _duration;
        newProposal.active = true;
        newProposal.proposer = msg.sender;
        
        proposalCount++;
        
        emit ProposalCreated(proposalId, msg.sender, _title);
    }
    
    /**
     * @dev Core Function 3: Cast quadratic votes on a proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _votes Number of votes to cast
     */
    function castVote(uint256 _proposalId, uint256 _votes) 
        external 
        onlyRegisteredVoter 
        validProposal(_proposalId) 
    {
        require(_votes > 0, "Vote count must be positive");
        
        // Calculate quadratic cost: cost = votes^2
        uint256 creditsRequired = _votes * _votes;
        
        // Check if voter has enough credits
        require(voters[msg.sender].availableCredits >= creditsRequired, 
                "Insufficient credits");
        
        // Update voter's credits and votes
        voters[msg.sender].availableCredits -= creditsRequired;
        
        // Update proposal data
        Proposal storage proposal = proposals[_proposalId];
        
        // If first time voting on this proposal
        if (proposal.voterCredits[msg.sender] == 0) {
            voters[msg.sender].participatedProposals++;
        }
        
        proposal.voterCredits[msg.sender] += creditsRequired;
        proposal.voterVotes[msg.sender] += _votes;
        proposal.totalVotes += _votes;
        proposal.totalCreditsUsed += creditsRequired;
        
        emit VoteCast(_proposalId, msg.sender, _votes, creditsRequired);
    }
    
    // View functions
    function getProposalDetails(uint256 _proposalId) 
        external 
        view 
        returns (
            string memory title,
            string memory description,
            uint256 totalVotes,
            uint256 totalCreditsUsed,
            uint256 deadline,
            bool active,
            address proposer
        ) 
    {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        
        return (
            proposal.title,
            proposal.description,
            proposal.totalVotes,
            proposal.totalCreditsUsed,
            proposal.deadline,
            proposal.active,
            proposal.proposer
        );
    }
    
    function getVoterInfo(address _voter) 
        external 
        view 
        returns (
            bool isRegistered,
            uint256 totalCredits,
            uint256 availableCredits,
            uint256 participatedProposals
        ) 
    {
        Voter storage voter = voters[_voter];
        return (
            voter.isRegistered,
            voter.totalCredits,
            voter.availableCredits,
            voter.participatedProposals
        );
    }
    
    function getVoterVotesOnProposal(uint256 _proposalId, address _voter) 
        external 
        view 
        returns (uint256 votes, uint256 creditsUsed) 
    {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        return (
            proposals[_proposalId].voterVotes[_voter],
            proposals[_proposalId].voterCredits[_voter]
        );
    }
    
    function calculateVotingCost(uint256 _votes) external pure returns (uint256) {
        return _votes * _votes;
    }
    
    // Admin functions
    function endProposal(uint256 _proposalId) external onlyAdmin {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(proposals[_proposalId].active, "Proposal already ended");
        
        proposals[_proposalId].active = false;
        emit ProposalEnded(_proposalId, proposals[_proposalId].totalVotes);
    }
    
    function addCreditsToVoter(address _voter, uint256 _credits) external onlyAdmin {
        require(voters[_voter].isRegistered, "Voter not registered");
        require(_credits > 0, "Credits must be positive");
        
        voters[_voter].totalCredits += _credits;
        voters[_voter].availableCredits += _credits;
    }
}