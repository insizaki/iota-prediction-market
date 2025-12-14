#[test_only]
module iota_contract_dev::prediction_market_tests;

use iota::coin::{Self, Coin};
use iota::iota::IOTA;
use iota::test_scenario::{Self as ts, Scenario};
use iota_contract_dev::prediction_market::{Self, Market, UserVote};
use std::string;

// Test addresses
const CREATOR: address = @0xA;
const VOTER1: address = @0xB;
const VOTER2: address = @0xC;
const VOTER3: address = @0xD;

// Helper function to create a test market that can be voted on (future deadline)
fun create_voteable_market(scenario: &mut Scenario) {
    ts::next_tx(scenario, CREATOR);
    {
        let question = string::utf8(b"Will it rain tomorrow?");
        let option_a = string::utf8(b"Yes");
        let option_b = string::utf8(b"No");
        let deadline = 1000000; // Future timestamp - allows voting

        prediction_market::create_market(
            question,
            option_a,
            option_b,
            deadline,
            ts::ctx(scenario),
        );
    };
}

// Helper function to create a test market that can be resolved (past deadline)
fun create_resolvable_market(scenario: &mut Scenario) {
    ts::next_tx(scenario, CREATOR);
    {
        let question = string::utf8(b"Will it rain tomorrow?");
        let option_a = string::utf8(b"Yes");
        let option_b = string::utf8(b"No");
        let deadline = 0; // Past deadline - allows immediate resolution

        prediction_market::create_market(
            question,
            option_a,
            option_b,
            deadline,
            ts::ctx(scenario),
        );
    };
}

#[test]
fun test_create_market() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    {
        let market = ts::take_shared<Market>(&scenario);

        let (
            creator,
            question,
            option_a,
            option_b,
            deadline,
            stake_a,
            stake_b,
            is_resolved,
            _,
        ) = prediction_market::get_market_info(&market);

        assert!(creator == CREATOR, 0);
        assert!(question == string::utf8(b"Will it rain tomorrow?"), 1);
        assert!(option_a == string::utf8(b"Yes"), 2);
        assert!(option_b == string::utf8(b"No"), 3);
        assert!(deadline == 1000000, 4);
        assert!(stake_a == 0, 5);
        assert!(stake_b == 0, 6);
        assert!(!is_resolved, 7);

        ts::return_shared(market);
    };

    ts::end(scenario);
}

#[test]
fun test_place_vote() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    // VOTER1 votes for option 0 (Yes) with 1000 IOTA
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));

        prediction_market::place_vote(
            &mut market,
            0, // option A
            stake,
            ts::ctx(&mut scenario),
        );

        let (stake_a, stake_b) = prediction_market::get_market_odds(&market);
        assert!(stake_a == 1000, 0);
        assert!(stake_b == 0, 1);

        ts::return_shared(market);
    };

    // Check that VOTER1 received UserVote object
    ts::next_tx(&mut scenario, VOTER1);
    {
        let user_vote = ts::take_from_sender<UserVote>(&scenario);
        let (_market_id, option, amount) = prediction_market::get_user_vote_info(&user_vote);

        assert!(option == 0, 2);
        assert!(amount == 1000, 3);

        ts::return_to_sender(&scenario, user_vote);
    };

    ts::end(scenario);
}

#[test]
fun test_multiple_votes() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    // VOTER1 votes for option 0 with 1000 IOTA
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));

        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // VOTER2 votes for option 1 with 2000 IOTA
    ts::next_tx(&mut scenario, VOTER2);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(2000, ts::ctx(&mut scenario));

        prediction_market::place_vote(&mut market, 1, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // VOTER3 votes for option 0 with 1500 IOTA
    ts::next_tx(&mut scenario, VOTER3);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1500, ts::ctx(&mut scenario));

        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // Check final odds
    ts::next_tx(&mut scenario, CREATOR);
    {
        let market = ts::take_shared<Market>(&scenario);
        let (stake_a, stake_b) = prediction_market::get_market_odds(&market);

        assert!(stake_a == 2500, 0); // 1000 + 1500
        assert!(stake_b == 2000, 1);

        let total_pool = prediction_market::get_total_pool(&market);
        assert!(total_pool == 4500, 2); // Total of all stakes

        ts::return_shared(market);
    };

    ts::end(scenario);
}

#[test]
fun test_resolve_market() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    // Add some votes
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // Creator resolves the market
    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut market = ts::take_shared<Market>(&scenario);

        prediction_market::resolve_market(&mut market, 0, ts::ctx(&mut scenario));

        assert!(prediction_market::is_market_resolved(&market), 0);

        ts::return_shared(market);
    };

    ts::end(scenario);
}

#[test]
fun test_claim_reward() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    // VOTER1 votes for option 0 with 1000 IOTA
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // VOTER2 votes for option 0 with 1000 IOTA (same winning option)
    ts::next_tx(&mut scenario, VOTER2);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // VOTER3 votes for option 1 with 2000 IOTA (losing option)
    ts::next_tx(&mut scenario, VOTER3);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(2000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 1, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // Creator resolves market with option 0 as winner
    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        prediction_market::resolve_market(&mut market, 0, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // VOTER1 claims reward
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let user_vote = ts::take_from_sender<UserVote>(&scenario);

        // Total pool = 4000, winning stake = 2000
        // VOTER1 stake = 1000
        // Reward = (1000 / 2000) * 4000 = 2000
        prediction_market::claim_reward(&mut market, user_vote, ts::ctx(&mut scenario));

        ts::return_shared(market);
    };

    // Verify VOTER1 received reward
    ts::next_tx(&mut scenario, VOTER1);
    {
        let reward = ts::take_from_sender<Coin<IOTA>>(&scenario);
        assert!(coin::value(&reward) == 2000, 0);
        ts::return_to_sender(&scenario, reward);
    };

    // VOTER2 claims reward
    ts::next_tx(&mut scenario, VOTER2);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let user_vote = ts::take_from_sender<UserVote>(&scenario);

        // VOTER2 should also get 2000 (same stake as VOTER1)
        prediction_market::claim_reward(&mut market, user_vote, ts::ctx(&mut scenario));

        ts::return_shared(market);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = prediction_market::EAlreadyVoted)]
fun test_cannot_vote_twice() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    // VOTER1 votes first time
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // VOTER1 tries to vote again - should fail
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = prediction_market::ENotCreator)]
fun test_only_creator_can_resolve() {
    let mut scenario = ts::begin(CREATOR);

    create_voteable_market(&mut scenario);

    // VOTER1 tries to resolve - should fail
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        prediction_market::resolve_market(&mut market, 0, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = prediction_market::EMarketResolved)]
fun test_cannot_vote_after_resolution() {
    let mut scenario = ts::begin(CREATOR);

    create_resolvable_market(&mut scenario);

    // Resolve market
    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        prediction_market::resolve_market(&mut market, 0, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    // Try to vote after resolution - should fail
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut market = ts::take_shared<Market>(&scenario);
        let stake = coin::mint_for_testing<IOTA>(1000, ts::ctx(&mut scenario));
        prediction_market::place_vote(&mut market, 0, stake, ts::ctx(&mut scenario));
        ts::return_shared(market);
    };

    ts::end(scenario);
}
