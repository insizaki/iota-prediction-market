# Ramal.in - IOTA Prediction Market 🔮

**Ramal.in** is a decentralized prediction market platform built on the IOTA blockchain. It allows users to create markets, place bets on outcomes using IOTA tokens, and claim rewards in a transparent and trustless environment.

![Ramal.in Dashboard](Screenshot%202025-12-14%20at%2016.58.56.png)

## 📂 Project Structure

- **`iota-contract-dev/`**: The Move smart contract for the prediction market.
- **`iota-frontend/`**: The Next.js web application (Dashboard & Landing Page).
- **`iota-project/`**: (Additional/Legacy Move resources).

---

## 🚀 Getting Started

Follow these steps to set up the project locally.

### 1. Smart Contract (`iota-contract-dev`)

First, you need to build and deploy the smart contract to the IOTA Testnet.

```bash
cd iota-contract-dev

# Build the contract
iota move build

# Run tests
iota move test

# Deploy to Testnet
iota client publish --gas-budget 100000000
```

> **Note**: After deployment, copy the **Package ID** from the output. You will need this for the frontend.

### 2. Frontend (`iota-frontend`)

Configure and run the web application.

#### Prerequisites
- Node.js (v18+)
- IOTA Wallet Extension (for browser interaction)

#### Setup

1. Navigate to the frontend directory:
   ```bash
   cd iota-frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. **Configuration**: 
   Open `app/lib/iota.ts` and update the `PACKAGE_ID` with your deployed package ID from step 1.
   ```typescript
   export const PACKAGE_ID = "0x..."; // Your Package ID here
   ```

4. Run the development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## ✨ Features

- **Create Markets**: Users can create new prediction markets with a question, two options (e.g., Yes/No), and a voting deadline.
- **Vote & Bet**: Users stake IOTA tokens on their predicted outcome. The logic prevents double voting and ensures bets are placed before the deadline.
- **Real-time Resolution**: The market creator can "Resolve" the market once the outcome is known.
- **Claim Rewards**: Winners can claim their share of the losing pool directly from the dashboard.
- **Dynamic UI**: Real-time progress bars showing the current pool distribution and odds.

## 🛠 Tech Stack

- **Blockchain**: IOTA Rebased (Move Language)
- **Frontend**: Next.js 16, TypeScript, Tailwind CSS v4
- **Integration**: `@iota/iota-sdk`, `@iota/dapp-kit`

## 📜 License
This project is part of the IOTA Workshop.
