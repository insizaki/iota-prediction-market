#[test_only]
module iota_rise::voting_tests_comprehensive;

use iota::test_scenario as ts;
use iota_rise::voting::{Self, Proposal};

#[test]
fun test_create_proposal() {
    let creator = @0xA;
    let mut scenario = ts::begin(creator);

    // Create proposal
    {
        voting::create_proposal(
            std::string::utf8(b"Should we adopt Move?"),
            ts::ctx(&mut scenario),
        );
    };

    // Verify proposal was created
    ts::next_tx(&mut scenario, creator);
    {
        let proposal = ts::take_shared<Proposal>(&scenario);

        let (yes, no) = voting::get_results(&proposal);
        assert!(yes == 0, 0);
        assert!(no == 0, 1);
        assert!(voting::is_active(&proposal), 2);
        assert!(voting::get_creator(&proposal) == creator, 3);

        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_voting_flow() {
    let creator = @0xA;
    let voter1 = @0xB;
    let voter2 = @0xC;
    let voter3 = @0xD;

    let mut scenario = ts::begin(creator);

    // Create proposal
    {
        voting::create_proposal(
            std::string::utf8(b"Increase pizza budget"),
            ts::ctx(&mut scenario),
        );
    };

    // Voter1 votes Yes
    ts::next_tx(&mut scenario, voter1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, true, ts::ctx(&mut scenario));
        assert!(voting::has_voted(&proposal, voter1), 0);
        ts::return_shared(proposal);
    };

    // Voter2 votes Yes
    ts::next_tx(&mut scenario, voter2);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, true, ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    // Voter3 votes No
    ts::next_tx(&mut scenario, voter3);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, false, ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    // Check results: 2 Yes, 1 No
    ts::next_tx(&mut scenario, creator);
    {
        let proposal = ts::take_shared<Proposal>(&scenario);
        let (yes, no) = voting::get_results(&proposal);
        assert!(yes == 2, 1);
        assert!(no == 1, 2);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0)] // EAlreadyVoted
fun test_double_vote_fails() {
    let creator = @0xA;
    let voter = @0xB;

    let mut scenario = ts::begin(creator);

    // Create proposal
    {
        voting::create_proposal(
            std::string::utf8(b"Test proposal"),
            ts::ctx(&mut scenario),
        );
    };

    // First vote (should succeed)
    ts::next_tx(&mut scenario, voter);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, true, ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    // Second vote (should fail)
    ts::next_tx(&mut scenario, voter);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, false, ts::ctx(&mut scenario)); // This should abort
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_close_proposal() {
    let creator = @0xA;
    let voter = @0xB;

    let mut scenario = ts::begin(creator);

    // Create and vote
    {
        voting::create_proposal(
            std::string::utf8(b"Test proposal"),
            ts::ctx(&mut scenario),
        );
    };

    ts::next_tx(&mut scenario, voter);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, true, ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    // Creator closes proposal
    ts::next_tx(&mut scenario, creator);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        assert!(voting::is_active(&proposal), 0);
        voting::close_proposal(&mut proposal, ts::ctx(&mut scenario));
        assert!(!voting::is_active(&proposal), 1);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 2)] // ENotCreator
fun test_non_creator_cannot_close() {
    let creator = @0xA;
    let non_creator = @0xB;

    let mut scenario = ts::begin(creator);

    // Create proposal
    {
        voting::create_proposal(
            std::string::utf8(b"Test proposal"),
            ts::ctx(&mut scenario),
        );
    };

    // Non-creator tries to close (should fail)
    ts::next_tx(&mut scenario, non_creator);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::close_proposal(&mut proposal, ts::ctx(&mut scenario)); // Should abort
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1)] // EProposalClosed
fun test_cannot_vote_on_closed_proposal() {
    let creator = @0xA;
    let voter = @0xB;

    let mut scenario = ts::begin(creator);

    // Create proposal
    {
        voting::create_proposal(
            std::string::utf8(b"Test proposal"),
            ts::ctx(&mut scenario),
        );
    };

    // Close proposal
    ts::next_tx(&mut scenario, creator);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::close_proposal(&mut proposal, ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    // Try to vote on closed proposal (should fail)
    ts::next_tx(&mut scenario, voter);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, true, ts::ctx(&mut scenario)); // Should abort
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_get_proposal_info() {
    let creator = @0xA;
    let voter = @0xB;

    let mut scenario = ts::begin(creator);

    // Create proposal
    {
        voting::create_proposal(
            std::string::utf8(b"Test detailed info"),
            ts::ctx(&mut scenario),
        );
    };

    // Vote
    ts::next_tx(&mut scenario, voter);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote(&mut proposal, true, ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    // Check comprehensive info
    ts::next_tx(&mut scenario, creator);
    {
        let proposal = ts::take_shared<Proposal>(&scenario);
        let (prop_creator, description, yes, no, active) = voting::get_proposal_info(&proposal);

        assert!(prop_creator == creator, 0);
        assert!(description == std::string::utf8(b"Test detailed info"), 1);
        assert!(yes == 1, 2);
        assert!(no == 0, 3);
        assert!(active == true, 4);

        ts::return_shared(proposal);
    };

    ts::end(scenario);
}
