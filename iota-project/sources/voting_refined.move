module iota_rise::voting_refined;

use iota::event;
use iota::object::UID;
use iota::table::Table;

/// Error codes
const EAlreadyVoted: u64 = 0;
const EProposalClosed: u64 = 1;
const ENotCreator: u64 = 2;

/// Event emitted when a proposal is created
public struct ProposalCreated has copy, drop {
    proposal_id: address,
    creator: address,
    description: std::string::String,
}

/// Event emitted when a vote is cast
public struct VoteCast has copy, drop {
    proposal_id: address,
    voter: address,
    choice: bool, // true = Yes, false = No
}

/// Event emitted when a proposal is closed
public struct ProposalClosed has copy, drop {
    proposal_id: address,
    final_yes_votes: u64,
    final_no_votes: u64,
}

public struct Proposal has key, store {
    id: UID,
    creator: address,
    description: std::string::String,
    yes_votes: u64,
    no_votes: u64,
    voters: Table<address, bool>,
    is_active: bool,
}

/// Create a new proposal with the given description
public entry fun create_proposal(
    description: std::string::String,
    ctx: &mut iota::tx_context::TxContext,
) {
    let sender = ctx.sender();
    let uid = iota::object::new(ctx);
    let proposal_id = uid.to_address();

    let proposal = Proposal {
        id: uid,
        creator: sender,
        description: description,
        yes_votes: 0,
        no_votes: 0,
        voters: iota::table::new(ctx),
        is_active: true,
    };

    event::emit(ProposalCreated {
        proposal_id,
        creator: sender,
        description: proposal.description,
    });

    iota::transfer::share_object(proposal);
}

/// Vote on a proposal (true = Yes, false = No)
public entry fun vote(
    proposal: &mut Proposal,
    choice: bool,
    ctx: &mut iota::tx_context::TxContext,
) {
    let sender = ctx.sender();

    // Check if proposal is still active
    assert!(proposal.is_active, EProposalClosed);

    // Check if sender has already voted
    assert!(!iota::table::contains(&proposal.voters, sender), EAlreadyVoted);

    // Record the vote
    iota::table::add(&mut proposal.voters, sender, choice);

    // Update vote counts
    if (choice) {
        proposal.yes_votes = proposal.yes_votes + 1;
    } else {
        proposal.no_votes = proposal.no_votes + 1;
    };

    // Emit vote event
    event::emit(VoteCast {
        proposal_id: proposal.id.to_address(),
        voter: sender,
        choice,
    });
}

/// Close a proposal (only creator can close)
public entry fun close_proposal(proposal: &mut Proposal, ctx: &iota::tx_context::TxContext) {
    let sender = ctx.sender();

    // Only creator can close the proposal
    assert!(proposal.creator == sender, ENotCreator);
    assert!(proposal.is_active, EProposalClosed);

    proposal.is_active = false;

    event::emit(ProposalClosed {
        proposal_id: proposal.id.to_address(),
        final_yes_votes: proposal.yes_votes,
        final_no_votes: proposal.no_votes,
    });
}

// === Getter Functions ===

/// Get voting results (yes_votes, no_votes)
public fun get_results(proposal: &Proposal): (u64, u64) {
    (proposal.yes_votes, proposal.no_votes)
}

/// Get proposal description
public fun get_description(proposal: &Proposal): std::string::String {
    proposal.description
}

/// Check if a specific address has voted
public fun has_voted(proposal: &Proposal, voter: address): bool {
    iota::table::contains(&proposal.voters, voter)
}

/// Check if proposal is active
public fun is_active(proposal: &Proposal): bool {
    proposal.is_active
}

/// Get proposal creator
public fun get_creator(proposal: &Proposal): address {
    proposal.creator
}

/// Get comprehensive proposal info
public fun get_proposal_info(
    proposal: &Proposal,
): (
    address, // creator
    std::string::String, // description
    u64, // yes_votes
    u64, // no_votes
    bool, // is_active
) {
    (
        proposal.creator,
        proposal.description,
        proposal.yes_votes,
        proposal.no_votes,
        proposal.is_active,
    )
}
