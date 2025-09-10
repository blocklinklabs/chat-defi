# Project Overview
See [README.md](./README.md)

---

### Why Rootstock?
Rootstock is a emerging leader in Bitcoin-based DeFi protocols and chatDeFi will help Rootstock's user optimize their DeFi gains via a simple easy-to-use chatbot to execute their desired DeFi strategies (allocate 80% to pool A and 20% to pool B) and manage risk (i.e. limit lost to 10% of portfolio).

### Rootstock "Everyday DeFi" Prize Requirements ###
- Smart Contract Deployment Address: 
    * See https://explorer.testnet.rootstock.io/address/0x2e30a7809aca616751f00ff46a0b4e9761ab71e2

- Front-end
    * See https://chatDeFi.app

- [x] 1) Clear short one-sentence description of your submission.
    * The [chatDeFi.app](http://chatdefi.app) AI agent democratizes DeFi by enabling anyone to create, execute, manage DeFi investment strategies by simply typing in their desired DeFi investment strategy into a user-friendly chatbot interface.

- [x] 2) Short description of what you integrated Rootstock with and how.
    * We wanted to interact with some of the lending protocols on RootStock but we couldn't find the pool contracts on the testnet so we deployed our own mock lending pool contracts and saw if our agent works fine with the mock lending pools and does all the required steps before smart contract execution
        - Demo Pool Address: https://explorer.testnet.rootstock.io/address/0x814b2fa4018cd54b1bbd8662a8b53feb4ed24d7d
        - Demo Token used as pool asset: https://explorer.testnet.rootstock.io/address/0xde1f15231e9bffcf6fcc9593bba852b0489b439c?__tab=transactions
        - Vault Contract: https://explorer.testnet.rootstock.io/address/0x2e30a7809aca616751f00ff46a0b4e9761ab71e2

- [x] 3) Short description of the team and their backgrounds.
    * Mike L. - PM, ex-front-end eng., CS/MBA degree. MIT grad.
    * Reza S. - full-stack web3 engineer 
    * Varad B. - full-stack engineer
    * Vasu G. - full-stack engineer
    * Devin T. - front-end engineer
- [x] 4) Clear instructions for testing the integration.
    * You can see the transactions done by the agent using the execute function from vault contract in the above provided links.

- [x] 5) Feedback describing your experience with building on Rootstock.
    * We integrated Rootstock as one of the supported chains in our platform. During development, we reached out to the Rootstock team to understand the current state of DeFi protocols on their network. At the time, there weren’t many lending protocols available on Rootstock mainnet. However, their team was incredibly supportive—one of their members suggested using mock pool contracts to simulate lending interactions for our demo. This guidance made it significantly easier to integrate and showcase our AI agent’s functionality on Rootstock, despite the limitations in available protocols.

- [x] 6) A short video demo or slide deck.
    * See Hackathon project submission for video URL
