#[test_only]
module iota_rise::voting_tests {
    use iota_rise::voting::{Self, Proposal};
    use iota::test_scenario;
    use std::string;

    #[test]
    fun test_create_vote_flow() {
        let owner = @0xA;
        let voter1 = @0xB;
        let voter2 = @0xC;

        let mut scenario = test_scenario::begin(owner);
        
        // 1. Create Proposal
        {
            voting::create_proposal(
                string::utf8(b"Vote for Pizza"),
                test_scenario::ctx(&mut scenario)
            );
        };

        // 2. Voter1 votes Yes
        test_scenario::next_tx(&mut scenario, voter1);
        {
            let mut proposal = test_scenario::take_shared<Proposal>(&scenario);
            voting::vote(&mut proposal, true, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(proposal);
        };

        // 3. Voter2 votes No
        test_scenario::next_tx(&mut scenario, voter2);
        {
            let mut proposal = test_scenario::take_shared<Proposal>(&scenario);
            voting::vote(&mut proposal, false, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(proposal);
        };

        // 4. Check results
        test_scenario::next_tx(&mut scenario, owner);
        {
            let proposal = test_scenario::take_shared<Proposal>(&scenario);
            let (yes, no) = voting::get_results(&proposal);
            assert!(yes == 1, 0);
            assert!(no == 1, 1);
            test_scenario::return_shared(proposal);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0)] // EAlreadyVoted = 0
    fun test_double_vote_fail() {
        let owner = @0xA;
        let voter1 = @0xB;

        let mut scenario = test_scenario::begin(owner);
        
        // 1. Create Proposal
        {
            voting::create_proposal(
                string::utf8(b"Vote for Pizza"),
                test_scenario::ctx(&mut scenario)
            );
        };

        // 2. Voter1 votes Yes
        test_scenario::next_tx(&mut scenario, voter1);
        {
            let mut proposal = test_scenario::take_shared<Proposal>(&scenario);
            voting::vote(&mut proposal, true, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(proposal);
        };

        // 3. Voter1 tries to vote again
        test_scenario::next_tx(&mut scenario, voter1);
        {
            let mut proposal = test_scenario::take_shared<Proposal>(&scenario);
            voting::vote(&mut proposal, false, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(proposal);
        };

        test_scenario::end(scenario);
    }
}
