if (
    secrets.alpacaKey == "" ||
    secrets.alpacaSecret === ""
  ) {
    throw Error(
      "need alpaca keys"
    )
  }
// @NB : change to fetch current balance of the stock get the stock name from args
  const token_symbol = args[0];
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
  
  const portfolioBalance = response.data.current_price
  console.log(`Alpaca Portfolio Balance: $${portfolioBalance}`)
  // The source code MUST return a Buffer or the request will return an error message
  // Use one of the following functions to convert to a Buffer representing the response bytes that are returned to the consumer smart contract:
  // - Functions.encodeUint256
  // - Functions.encodeInt256
  // - Functions.encodeString
  // Or return a custom Buffer for a custom byte encoding
  return Functions.encodeUint256(Math.round(portfolioBalance * 1000000000000000000))