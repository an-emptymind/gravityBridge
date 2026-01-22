#!/bin/bash
npx ts-node \
contract-deployer.ts \
--cosmos-node="http://localhost:1317" \
--eth-node="http://localhost:8545" \
--eth-privkey="pvt_key" \
--contract=Gravity.json \
--contractERC721=GravityERC721.json \
--test-mode=true
