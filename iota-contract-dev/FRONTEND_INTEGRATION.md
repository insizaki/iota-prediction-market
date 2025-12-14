# Frontend Integration Guide for IOTA Prediction Market

This guide provides technical details for integrating the Prediction Market smart contract into a frontend application (e.g., Next.js) using the IOTA TypeScript SDK.

## 📋 Contract Details

**Note**: You must deploy the contract to get the actual Package ID.

```typescript
const PACKAGE_ID = "0x..."; // Replace with your deployed Package ID
const MODULE_NAME = "prediction_market";
const NETWORK = "testnet"; // or 'devnet', 'mainnet'
```

## 🛠 Prerequisites

Install the IOTA SDK:
```bash
npm install @iota/iota-sdk
```

## 📦 Data Types (TypeScript Interfaces)

Mirroring the Move structs for type safety in your frontend.

```typescript
export interface Market {
  id: { id: string };
  creator: string;
  question: string;
  option_a: string;
  option_b: string;
  deadline: string; // u64 comes as string in JSON
  total_stake_a: string;
  total_stake_b: string;
  pool: { value: string };
  is_resolved: boolean;
  winning_option: number; // u8
}

export interface UserVote {
  id: { id: string };
  market_id: string;
  chosen_option: number;
  stake_amount: string;
}
```

## 🔌 Client Setup

```typescript
import { IotaClient, getFullnodeUrl } from '@iota/iota-sdk/client';

const client = new IotaClient({
  url: getFullnodeUrl('testnet'),
});
```

## 📖 Reading Data

### Fetch Single Market
```typescript
async function getMarket(marketId: string): Promise<Market | null> {
  const result = await client.getObject({
    id: marketId,
    options: {
      showContent: true,
    }
  });

  if (result.data?.content?.dataType === 'moveObject') {
    return result.data.content.fields as unknown as Market;
  }
  return null;
}
```

### Fetch User's Vote for a Market
In IOTA objects are owned. You query objects owned by the user and filter by type.

```typescript
async function getUserVote(userAddress: string, marketId: string) {
  const { data } = await client.getOwnedObjects({
    owner: userAddress,
    filter: {
      StructType: `${PACKAGE_ID}::${MODULE_NAME}::UserVote`
    },
    options: { showContent: true }
  });

  // Find the vote corresponding to the specific market
  return data.find(obj => 
    (obj.data?.content as any)?.fields?.market_id === marketId
  );
}
```

## ✍️ Writing Data (Transactions)

Using `TransactionBlock` from scalar SDK.

### 1. Create Market
```typescript
import { TransactionBlock } from '@iota/iota-sdk/transactions';

async function createMarket(signer: any, question: string, optA: string, optB: string, deadlineSrc: number) {
  const tx = new TransactionBlock();
  
  tx.moveCall({
    target: `${PACKAGE_ID}::${MODULE_NAME}::create_market`,
    arguments: [
      tx.pure.string(question),
      tx.pure.string(optA),
      tx.pure.string(optB),
      tx.pure.u64(deadlineSrc),
    ],
  });

  return signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
}
```

### 2. Place Vote
This involves taking a coin from the user's wallet, splitting it (if needed), and passing it to the contract.

```typescript
async function placeVote(signer: any, marketId: string, option: number, amount: number) {
  const tx = new TransactionBlock();

  // Split coin for the stake amount
  const [stakeCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(amount)]);

  tx.moveCall({
    target: `${PACKAGE_ID}::${MODULE_NAME}::place_vote`,
    arguments: [
      tx.object(marketId),
      tx.pure.u8(option),
      stakeCoin,
    ],
  });

  return signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
}
```

### 3. Resolve Market (Creator Only)
```typescript
async function resolveMarket(signer: any, marketId: string, winningOption: number) {
  const tx = new TransactionBlock();

  tx.moveCall({
    target: `${PACKAGE_ID}::${MODULE_NAME}::resolve_market`,
    arguments: [
      tx.object(marketId),
      tx.pure.u8(winningOption),
    ],
  });

  return signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
}
```

### 4. Claim Reward
```typescript
async function claimReward(signer: any, marketId: string, userVoteId: string) {
  const tx = new TransactionBlock();

  tx.moveCall({
    target: `${PACKAGE_ID}::${MODULE_NAME}::claim_reward`,
    arguments: [
      tx.object(marketId),
      tx.object(userVoteId),
    ],
  });

  return signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
}
```

## 📡 Events
Listen for these events to update your UI in real-time.

```typescript
// Filter strings
const EVENTS = {
  MarketCreated: `${PACKAGE_ID}::${MODULE_NAME}::MarketCreated`,
  VotePlaced: `${PACKAGE_ID}::${MODULE_NAME}::VotePlaced`,
  MarketResolved: `${PACKAGE_ID}::${MODULE_NAME}::MarketResolved`,
  RewardClaimed: `${PACKAGE_ID}::${MODULE_NAME}::RewardClaimed`,
};

// Example subscription
const unsubscribe = await client.on(
  "message",
  (message) => {
    if (message.type === EVENTS.VotePlaced) {
      console.log("New vote placed:", message.parsedJson);
      // Refresh odds
    }
  },
  { filter: { MoveModule: { package: PACKAGE_ID, module: MODULE_NAME } } }
);
```

## 🧮 Odds Calculation (Frontend Helper)

Use the raw stake values to display odds or percentages.

```typescript
function calculatePercentages(stakeA: string, stakeB: string) {
  const a =  Number(stakeA);
  const b = Number(stakeB);
  const total = a + b;

  if (total === 0) return { a: 50, b: 50 };

  return {
    a: (a / total) * 100,
    b: (b / total) * 100
  };
}
```
