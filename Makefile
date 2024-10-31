-include .env

.PHONY: deploy

deploy:; @forge script script/TokenBizz.s.sol --private-key ${PRIVATE_KEY} --rpc-url ${ABITRUM_URL} --etherscan-api-key ${ABITRUM_API_KEY} --priority-gas-price 1 --verify --broadcast -vvv