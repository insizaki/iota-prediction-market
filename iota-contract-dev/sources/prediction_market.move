module iota_contract_dev::prediction_market;

use iota::balance::{Self, Balance};
use iota::coin::{Self, Coin};
use iota::event;
use iota::iota::IOTA;
use iota::table::{Self, Table};
use std::string::String;

// ==================== Error Codes ====================

/// Market has already been resolved
const EMarketResolved: u64 = 0;
/// Voting deadline has passed
const EDeadlinePassed: u64 = 1;
/// Deadline has not been reached yet
const EDeadlineNotReached: u64 = 2;
/// Only the market creator can perform this operation
const ENotCreator: u64 = 3;
/// User has already voted in this market
const EAlreadyVoted: u64 = 4;
/// Invalid option (must be 0 or 1)
const EInvalidOption: u64 = 5;
/// User voted for the losing option
const EWrongOption: u64 = 6;
/// Market has not been resolved yet
const ENotResolved: u64 = 7;
/// Insufficient stake amount
const EInsufficientStake: u64 = 8;

// ==================== Data Structures ====================

/// Represents a prediction market
public struct Market has key, store {
    id: UID,
    /// Address of the market creator (acts as oracle)
    creator: address,
    /// The question or topic of the market
    question: String,
    /// First option (e.g., "Yes" or custom option)
    option_a: String,
    /// Second option (e.g., "No" or custom option)
    option_b: String,
    /// Unix timestamp when voting closes
    deadline: u64,
    /// Total IOTA staked on option A (0)
    total_stake_a: u64,
    /// Total IOTA staked on option B (1)
    total_stake_b: u64,
    /// Total pool of all stakes
    pool: Balance<IOTA>,
    /// Whether the market has been resolved
    is_resolved: bool,
    /// The winning option (0 or 1), only valid after resolution
    winning_option: u8,
    /// Track which addresses have voted to prevent double voting
    voters: Table<address, bool>,
}

/// Represents a user's vote in a specific market
/// This is an owned object that serves as proof of participation
public struct UserVote has key, store {
    id: UID,
    /// The market this vote belongs to
    market_id: address,
    /// The option chosen (0 for option_a, 1 for option_b)
    chosen_option: u8,
    /// The amount of IOTA staked
    stake_amount: u64,
}

// ==================== Events ====================

/// Emitted when a new market is created
public struct MarketCreated has copy, drop {
    market_id: address,
    creator: address,
    question: String,
    option_a: String,
    option_b: String,
    deadline: u64,
}

/// Emitted when a user places a vote
public struct VotePlaced has copy, drop {
    market_id: address,
    voter: address,
    chosen_option: u8,
    stake_amount: u64,
}

/// Emitted when a market is resolved
public struct MarketResolved has copy, drop {
    market_id: address,
    winning_option: u8,
    total_stake_a: u64,
    total_stake_b: u64,
}

/// Emitted when a user claims their reward
public struct RewardClaimed has copy, drop {
    market_id: address,
    winner: address,
    reward_amount: u64,
}

// ==================== Public Entry Functions ====================

/// Create a new prediction market
///
/// # Arguments
/// * `question` - The question or topic of the market
/// * `option_a` - First option (e.g., "Yes")
/// * `option_b` - Second option (e.g., "No")
/// * `deadline` - Unix timestamp when voting closes
/// * `ctx` - Transaction context
public entry fun create_market(
    question: String,
    option_a: String,
    option_b: String,
    deadline: u64,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    let uid = object::new(ctx);
    let market_id = uid.to_address();

    let market = Market {
        id: uid,
        creator: sender,
        question,
        option_a,
        option_b,
        deadline,
        total_stake_a: 0,
        total_stake_b: 0,
        pool: balance::zero<IOTA>(),
        is_resolved: false,
        winning_option: 0,
        voters: table::new(ctx),
    };

    // Emit event
    event::emit(MarketCreated {
        market_id,
        creator: sender,
        question: market.question,
        option_a: market.option_a,
        option_b: market.option_b,
        deadline: market.deadline,
    });

    // Share the market object so anyone can interact with it
    transfer::share_object(market);
}

/// Place a vote on a market by staking IOTA tokens
///
/// # Arguments
/// * `market` - The market to vote on
/// * `option` - The option to vote for (0 for option_a, 1 for option_b)
/// * `stake` - The IOTA coins to stake
/// * `ctx` - Transaction context
public entry fun place_vote(
    market: &mut Market,
    option: u8,
    stake: Coin<IOTA>,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    let current_time = ctx.epoch_timestamp_ms() / 1000; // Convert to seconds

    // Validations
    assert!(!market.is_resolved, EMarketResolved);
    assert!(current_time < market.deadline, EDeadlinePassed);
    assert!(option == 0 || option == 1, EInvalidOption);
    assert!(!table::contains(&market.voters, sender), EAlreadyVoted);

    let stake_amount = coin::value(&stake);
    assert!(stake_amount > 0, EInsufficientStake);

    // Add stake to the pool
    let stake_balance = coin::into_balance(stake);
    balance::join(&mut market.pool, stake_balance);

    // Update total stakes based on chosen option
    if (option == 0) {
        market.total_stake_a = market.total_stake_a + stake_amount;
    } else {
        market.total_stake_b = market.total_stake_b + stake_amount;
    };

    // Mark voter as having voted
    table::add(&mut market.voters, sender, true);

    // Create UserVote object for the user
    let market_id = object::id_address(market);
    let user_vote = UserVote {
        id: object::new(ctx),
        market_id,
        chosen_option: option,
        stake_amount,
    };

    // Emit event
    event::emit(VotePlaced {
        market_id,
        voter: sender,
        chosen_option: option,
        stake_amount,
    });

    // Transfer UserVote to the voter
    transfer::transfer(user_vote, sender);
}

/// Resolve the market by setting the winning option
/// Only callable by the market creator after the deadline
///
/// # Arguments
/// * `market` - The market to resolve
/// * `winning_option` - The winning option (0 or 1)
/// * `ctx` - Transaction context
public entry fun resolve_market(market: &mut Market, winning_option: u8, ctx: &TxContext) {
    let sender = ctx.sender();
    // Validations
    assert!(sender == market.creator, ENotCreator);
    assert!(!market.is_resolved, EMarketResolved);
    assert!(winning_option == 0 || winning_option == 1, EInvalidOption);

    // Mark as resolved and set winner
    market.is_resolved = true;
    market.winning_option = winning_option;

    // Emit event
    let market_id = object::id_address(market);
    event::emit(MarketResolved {
        market_id,
        winning_option,
        total_stake_a: market.total_stake_a,
        total_stake_b: market.total_stake_b,
    });
}

/// Claim reward from a resolved market
/// User must have voted for the winning option
/// Reward calculation: (user_stake / total_winning_stake) * total_pool
///
/// # Arguments
/// * `market` - The resolved market
/// * `user_vote` - The user's vote object (consumed)
/// * `ctx` - Transaction context
public entry fun claim_reward(market: &mut Market, user_vote: UserVote, ctx: &mut TxContext) {
    let sender = ctx.sender();

    // Validations
    assert!(market.is_resolved, ENotResolved);

    let UserVote {
        id,
        market_id,
        chosen_option,
        stake_amount,
    } = user_vote;

    // Verify this vote is for this market
    assert!(market_id == object::id_address(market), EWrongOption);

    // Verify user voted for the winning option
    assert!(chosen_option == market.winning_option, EWrongOption);

    // Calculate reward
    let total_winning_stake = if (market.winning_option == 0) {
        market.total_stake_a
    } else {
        market.total_stake_b
    };

    // If there are no winning stakes, cannot claim (edge case)
    assert!(total_winning_stake > 0, EWrongOption);

    let total_pool = balance::value(&market.pool);

    // Reward = (user_stake / total_winning_stake) * total_pool
    // Using integer math: (user_stake * total_pool) / total_winning_stake
    let reward_amount = (stake_amount * total_pool) / total_winning_stake;

    // Extract reward from pool
    let reward_balance = balance::split(&mut market.pool, reward_amount);
    let reward_coin = coin::from_balance(reward_balance, ctx);

    // Emit event
    let market_id = object::id_address(market);
    event::emit(RewardClaimed {
        market_id,
        winner: sender,
        reward_amount,
    });

    // Transfer reward to user
    transfer::public_transfer(reward_coin, sender);

    // Delete the UserVote object
    object::delete(id);
}

// ==================== View Functions ====================

/// Get the current odds (total stakes) for both options
/// Returns (total_stake_a, total_stake_b)
public fun get_market_odds(market: &Market): (u64, u64) {
    (market.total_stake_a, market.total_stake_b)
}

/// Get comprehensive market information
public fun get_market_info(
    market: &Market,
): (
    address, // creator
    String, // question
    String, // option_a
    String, // option_b
    u64, // deadline
    u64, // total_stake_a
    u64, // total_stake_b
    bool, // is_resolved
    u8, // winning_option
) {
    (
        market.creator,
        market.question,
        market.option_a,
        market.option_b,
        market.deadline,
        market.total_stake_a,
        market.total_stake_b,
        market.is_resolved,
        market.winning_option,
    )
}

/// Check if market is resolved
public fun is_market_resolved(market: &Market): bool {
    market.is_resolved
}

/// Get market deadline
public fun get_deadline(market: &Market): u64 {
    market.deadline
}

/// Get market creator
public fun get_creator(market: &Market): address {
    market.creator
}

/// Get market question
public fun get_question(market: &Market): String {
    market.question
}

/// Get market options
public fun get_options(market: &Market): (String, String) {
    (market.option_a, market.option_b)
}

/// Get total pool value
public fun get_total_pool(market: &Market): u64 {
    balance::value(&market.pool)
}

/// Check if an address has voted
public fun has_voted(market: &Market, voter: address): bool {
    table::contains(&market.voters, voter)
}

/// Get user vote information
public fun get_user_vote_info(user_vote: &UserVote): (address, u8, u64) {
    (user_vote.market_id, user_vote.chosen_option, user_vote.stake_amount)
}
