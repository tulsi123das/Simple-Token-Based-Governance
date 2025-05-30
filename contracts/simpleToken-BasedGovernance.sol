// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleTokenBasedGovernance
 * @dev A simple governance contract that allows token holders to create and vote on proposals
 */
contract Project is ERC20, Ownable, ReentrancyGuard {
    
    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool exists;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice; // true = for, false = against
    }
    
    // State variables
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    uint256 public votingDuration = 7 days;
    uint256 public proposalThreshold = 1000 * 10**18; // 1000 tokens required to create proposal
    uint256 public quorumThreshold = 10; // 10% of total supply needed for quorum
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    
    event ProposalExecuted(uint256 indexed proposalId);
    
    event VotingDurationUpdated(uint256 newDuration);
    event ProposalThresholdUpdated(uint256 newThreshold);
    event QuorumThresholdUpdated(uint256 newThreshold);
    
    constructor() ERC20("GovernanceToken", "GOV") Ownable(msg.sender) {
        // Mint initial supply to deployer
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }
    
    /**
     * @dev Create a new proposal
     * @param title The title of the proposal
     * @param description The detailed description of the proposal
     */
    function createProposal(
        string memory title,
        string memory description
    ) external returns (uint256) {
        require(balanceOf(msg.sender) >= proposalThreshold, "Insufficient tokens to create proposal");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        uint256 proposalId = proposalCount++;
        Proposal storage newProposal = proposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingDuration;
        newProposal.executed = false;
        newProposal.exists = true;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            newProposal.startTime,
            newProposal.endTime
        );
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param support True for 'for', false for 'against'
     */
    function vote(uint256 proposalId, bool support) external {
        require(proposals[proposalId].exists, "Proposal does not exist");
        require(block.timestamp >= proposals[proposalId].startTime, "Voting has not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting has ended");
        require(!proposals[proposalId].hasVoted[msg.sender], "Already voted");
        require(balanceOf(msg.sender) > 0, "No voting power");
        
        Proposal storage proposal = proposals[proposalId];
        uint256 weight = balanceOf(msg.sender);
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;
        
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    /**
     * @dev Execute a proposal if it has passed
     * @param proposalId The ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        require(proposals[proposalId].exists, "Proposal does not exist");
        require(block.timestamp > proposals[proposalId].endTime, "Voting is still active");
        require(!proposals[proposalId].executed, "Proposal already executed");
        
        Proposal storage proposal = proposals[proposalId];
        
        // Check if proposal passed
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalSupply() * quorumThreshold) / 100;
        
        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal did not pass");
        
        proposal.executed = true;
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Get proposal details
     * @param proposalId The ID of the proposal
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool exists
    ) {
        require(proposals[proposalId].exists, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.exists
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId The ID of the proposal
     * @param voter The address to check
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        require(proposals[proposalId].exists, "Proposal does not exist");
        return proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Get the vote choice of an address for a proposal
     * @param proposalId The ID of the proposal
     * @param voter The address to check
     */
    function getVoteChoice(uint256 proposalId, address voter) external view returns (bool) {
        require(proposals[proposalId].exists, "Proposal does not exist");
        require(proposals[proposalId].hasVoted[voter], "Address has not voted");
        return proposals[proposalId].voteChoice[voter];
    }
    
    /**
     * @dev Check if a proposal has reached quorum and passed
     * @param proposalId The ID of the proposal
     */
    function proposalPassed(uint256 proposalId) external view returns (bool) {
        require(proposals[proposalId].exists, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalSupply() * quorumThreshold) / 100;
        
        return totalVotes >= requiredQuorum && proposal.forVotes > proposal.againstVotes;
    }
    
    // Owner functions for governance parameter updates
    
    /**
     * @dev Update voting duration (only owner)
     * @param newDuration New voting duration in seconds
     */
    function updateVotingDuration(uint256 newDuration) external onlyOwner {
        require(newDuration >= 1 days && newDuration <= 30 days, "Invalid duration");
        votingDuration = newDuration;
        emit VotingDurationUpdated(newDuration);
    }
    
    /**
     * @dev Update proposal threshold (only owner)
     * @param newThreshold New threshold in wei (token units)
     */
    function updateProposalThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0, "Threshold must be greater than 0");
        proposalThreshold = newThreshold;
        emit ProposalThresholdUpdated(newThreshold);
    }
    
    /**
     * @dev Update quorum threshold (only owner)
     * @param newThreshold New quorum threshold as percentage (1-100)
     */
    function updateQuorumThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0 && newThreshold <= 100, "Invalid threshold percentage");
        quorumThreshold = newThreshold;
        emit QuorumThresholdUpdated(newThreshold);
    }
    
    /**
     * @dev Mint additional tokens (only owner)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Get current governance parameters
     */
    function getGovernanceParams() external view returns (
        uint256 currentVotingDuration,
        uint256 currentProposalThreshold,
        uint256 currentQuorumThreshold,
        uint256 currentProposalCount
    ) {
        return (
            votingDuration,
            proposalThreshold,
            quorumThreshold,
            proposalCount
        );
    }
}
