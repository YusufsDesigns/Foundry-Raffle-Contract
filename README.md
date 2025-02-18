# Smart Contract Lottery

This project implements a decentralized lottery system using Ethereum smart contracts. Users can enter the raffle by depositing an amount of ETH worth $5. The winner is selected through a fair, transparent process powered by Chainlink's Verifiable Random Function (VRF). Additionally, the contract is automated with Chainlink Automation, ensuring no manual intervention is needed for checking raffle status and selecting winners.

## Features:
- **Enter the raffle** by depositing $5 worth of ETH.
- **Winner selection** via Chainlink VRF for fairness and transparency.
- **Automated execution** using Chainlink Automation for seamless management.

## Setup

### Prerequisites:
- [Foundry](https://book.getfoundry.sh/) for building and testing smart contracts.
- [Chainlink VRF](https://chain.link/) for randomness.
- [Chainlink Automation](https://chain.link/) for automated contract execution.

### Installation:
1. Clone the repository:
    ```bash
    git clone https://github.com/YusufsDesigns/Smart-contract-lottery.git
    cd Smart-contract-lottery
    ```
2. Install dependencies:
    ```bash
    forge install
    ```

### Testing the contract:
To build the project:
```bash
forge build
```

To run tests:
```bash
forge test
```

### Deploy:
Deploy the contract to Ethereum or a testnet by running:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url <rpc_url> --private-key <private_key>
```

### Interact with Contract:
Use `cast` or Remix to interact with the contract after deployment.

## Contribution:
Feel free to fork and contribute to the project. Pull requests with new features or bug fixes are welcome!

---

This README provides a complete overview of the lottery contract, installation, testing, and deployment instructions. Let me know if you need further adjustments!
