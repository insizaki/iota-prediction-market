# IOTA Prediction Market Smart Contract

## Overview
A decentralized mini prediction market built on IOTA Move that allows users to create markets, place votes with token stakes, and claim proportional rewards.

## Features

### ✅ Market Creation
- Create markets with custom questions and two options (e.g., "Yes/No")
- Set voting deadlines (Unix timestamp)
- No initial liquidity required

### ✅ Voting/Betting
- Stake IOTA tokens on your predicted outcome
- Real-time odds based on total stakes per option
- One vote per user per market (prevents double voting)
- Vote before deadline only

### ✅ Market Resolution
- Market creator acts as oracle
- Resolve market after deadline passes
- Set the winning option (0 or 1)

### ✅ Reward Distribution
- Winners claim proportional rewards
- Formula: `(user_stake / total_winning_stake) * total_pool`
- Losers' stakes go to winners
- Simple, fair distribution

## Contract Structure

### Data Structures

**Market** (Shared Object)
```move
- id: UID
- creator: address
- question: String
- option_a: String
- option_b: String  
- deadline: u64
- total_stake_a: u64
- total_stake_b: u64
- pool: Balance<IOTA>
- is_resolved: bool
- winning_option: u8
- voters: Table<address, bool>
```

**UserVote** (Owned Object)
```move
- id: UID
- market_id: address
- chosen_option: u8
- stake_amount: u64
```

### Main Functions

#### 1. `create_market`
```move
public entry fun create_market(
    question: String,
    option_a: String,
    option_b: String,
    deadline: u64,
    ctx: &mut TxContext,
)
```
Creates a new prediction market with specified parameters.

#### 2. `place_vote`
```move
public entry fun place_vote(
    market: &mut Market,
    option: u8,  // 0 or 1
    stake: Coin<IOTA>,
    ctx: &mut TxContext,
)
```
Places a vote by staking IOTA tokens. Returns a `UserVote` object to the caller.

**Validations:**
- Market not resolved
- Before deadline
- Valid option (0 or 1)
- User hasn't voted yet
- Stake amount > 0

#### 3. `resolve_market`
```move
public entry fun resolve_market(
    market: &mut Market,
    winning_option: u8,
    ctx: &TxContext,
)
```
Resolves the market by setting the winning option. Only callable by market creator after deadline.

#### 4. `claim_reward`
```move
public entry fun claim_reward(
    market: &mut Market,
    user_vote: UserVote,
    ctx: &mut TxContext,
)
```
Claims reward for winning voters. Consumes the `UserVote` object.

**Reward Calculation:**
```
reward = (user_stake_amount * total_pool) / total_winning_stake
```

#### 5. `get_market_odds`
```move
public fun get_market_odds(market: &Market): (u64, u64)
```
Returns current stakes for both options.

### View Functions
- `get_market_info()` - Get all market details
- `is_market_resolved()` - Check resolution status
- `get_deadline()` - Get market deadline
- `get_creator()` - Get market creator
- `get_question()` - Get market question
- `get_options()` - Get both options
- `get_total_pool()` - Get total pool value
- `has_voted()` - Check if address voted
- `get_user_vote_info()` - Get vote details

## Usage Example

> 💡 **Frontend Developers**: Check out [FRONTEND_INTEGRATION.md](./FRONTEND_INTEGRATION.md) for a complete guide on connecting this contract to a Next.js/React app using TypeScript and the IOTA SDK.

### 1. Create a Market
```bash
iota client call --package <PACKAGE_ID> \
  --module prediction_market \
  --function create_market \
  --args "Will it rain tomorrow?" "Yes" "No" 1734192000
```

### 2. Place a Vote
```bash
iota client call --package <PACKAGE_ID> \
  --module prediction_market \
  --function place_vote \
  --args <MARKET_ID> 0 <COIN_OBJECT_ID>
```

### 3. Resolve Market (Creator Only)
```bash
iota client call --package <PACKAGE_ID> \
  --module prediction_market \
  --function resolve_market \
  --args <MARKET_ID> 0
```

### 4. Claim Rewards (Winners)
```bash
iota client call --package <PACKAGE_ID> \
  --module prediction_market \
  --function claim_reward \
  --args <MARKET_ID> <USER_VOTE_ID>
```

## Building and Testing

### Build
```bash
cd iota-contract-dev
iota move build
```

### Test
```bash
iota move test
```

### Deploy
```bash
iota client publish --gas-budget 100000000
```

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | `EMarketResolved` | Market already resolved |
| 1 | `EDeadlinePassed` | Cannot vote after deadline |
| 2 | `EDeadlineNotReached` | Cannot resolve before deadline |
| 3 | `ENotCreator` | Only creator can resolve |
| 4 | `EAlreadyVoted` | User already voted |
| 5 | `EInvalidOption` | Option must be 0 or 1 |
| 6 | `EWrongOption` | User voted for losing option |
| 7 | `ENotResolved` | Market not yet resolved |
| 8 | `EInsufficientStake` | Stake must be > 0 |

## Events

- `MarketCreated` - Emitted when market is created
- `VotePlaced` - Emitted when user votes
- `MarketResolved` - Emitted when market is resolved
- `RewardClaimed` - Emitted when user claims reward

## Security Considerations

1. **Oracle Trust**: Market creator acts as oracle. Can be upgraded to decentralized voting later.
2. **Double Voting Prevention**: Uses `Table` to track voters and owned `UserVote` objects.
3. **Integer Math**: Reward calculation uses integer arithmetic to avoid rounding errors.
4. **Access Control**: Only creator can resolve markets.
5. **Time Validation**: Checks deadline for voting and resolution.

## Future Enhancements

- [ ] Decentralized oracle (voting-based resolution)
- [ ] Platform fees
- [ ] Multiple outcome support (>2 options)
- [ ] Liquidity pools
- [ ] Automated market maker (AMM) for dynamic odds
- [ ] Market cancellation mechanism
- [ ] Dispute resolution

## License
This is a workshop/educational project for IOTA Move development.

## Author
Created for IOTA Move Workshop - Day 3
