if (
    secrets.alpacaKey == "" ||
    secrets.alpacaSecret === ""
  ) {
    throw Error(
      "need alpaca keys"
    )
  }
  

  // @NB : get total amount of token in our bank or brokerage
  
  const token_symbol = args[1];
  // const token_symbol = "TSLA";
  console.log(`this is the token symbol ${token_symbol}`);
  
  const alpacaRequest = Functions.makeHttpRequest({
    url: `https://paper-api.alpaca.markets/v2/positions/${token_symbol}`,
    headers: {
      accept: 'application/json',
      'APCA-API-KEY-ID': secrets.alpacaKey,
      'APCA-API-SECRET-KEY': secrets.alpacaSecret
    }
  })
  
  const [response] = await Promise.all([
    alpacaRequest,
  ])

  console.log(response);
  
  
  const portfolioBalance = response.data.qty
  console.log(`Alpaca Portfolio Balance: $${portfolioBalance}`)
  // The source code MUST return a Buffer or the request will return an error message
  // Use one of the following functions to convert to a Buffer representing the response bytes that are returned to the consumer smart contract:
  // - Functions.encodeUint256
  // - Functions.encodeInt256
  // - Functions.encodeString
  // Or return a custom Buffer for a custom byte encoding
  return Functions.encodeUint256(Math.round(portfolioBalance * 1000000000000000000))