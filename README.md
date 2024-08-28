# quantecon_and_likes
Exercises/concepts I came across while studying the (julia) quantecon course/and or while reading John C. Hull's derivative book.

## Trading Strategies
### Cross Asset Skew

Corss asset skew trading refers to a trading strategy (see: [paper]([https://elsevier-ssrn-document-store-prod.s3.amazonaws.com/19/12/17/ssrn_id3505422_code2771280.pdf?response-content-disposition=inline&X-Amz-Security-Token=IQoJb3JpZ2luX2VjELD%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJFMEMCHx8xL8a7bQ%2Frrrk5Wdgtpf6DBHchspqA%2BlUeMUcHubYCIHQtH1e6wKtMw7zuog3UzvXxIVK6AbF5Jxp4NfCtiDNZKscFCLn%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQBBoMMzA4NDc1MzAxMjU3IgyYnPfg7muHi1VBR1YqmwWS2Njd6LH%2BoWWKCF7hkLa3cpBX9my4SWWjQaJPE%2BfiGsyJPIY2TU6djD1xuogjQ%2B5cONoMVFr9wi%2FeWGhjtdY6cC5MxX6%2FvB9Z9Cf6gtNNFEV%2FezFB6B21IsNypaEud0NAlJnq9cCuKstiFhiTDODBELL3DQYmPt4MtfqGceXT78TnQhPIckvxcPGYKWggPFeC7%2FJUoiKMGY%2BreKFLi1hIEbwCZNcF%2BohAk1yU6s48vDvaHHQfbL9tA%2F5vcVQ2%2BlDkpV%2BBzr9ibms1b1d9dAn9D4v2poyK4Nl3%2BgXgesXKK3ex6Rw%2BiM0QwDFZ%2B%2B9x3akeVYlFpBR6iiYeV64nJjV7K%2Fssrf2ndp3B8oRCTC1htKh2F5X4c%2BgYjixnLGTLgoIFBt4ic66QIxKvq4kxYJZS%2FqJFNxZJhHee9YBPsSZP2Byb%2B34PZZgvWWlm6iYBxLg4rohkvxmL4yPL3PFEG%2F37k%2FWjvdd0bZbAoEHKzQBgMwrfGyRzivpmPfJp%2FF41JzVpcEUUaGNMajjnoaq%2BsQYtZU4PkqXXT1kqKZt3uXsdHT30av7%2BiF8uyjvqcPy8Gobv42poAu%2BbzQJ6Xk47Oy8bHCUAW6DB%2B3Phgq9qYywiDQfJ%2Fp1dGTveu1Q1Z9r1FM%2BMaI1rpdx%2FIsV071k8Nlph0fRkDCEJsah7kvw9Jh9OCA%2FQTY%2BouzEoeq28mV8UD7Rg9NBW75ZzuRaXpdz7c3qk2S98FH4sOdwRufVFef9W4s4sDOxNeHPI2EyyvVlKc1%2By1R64fFhjAJhyWDnRoswDxWGV4b4Q0v%2FWTF1xSVOgEp7fNAli8XhdVuwM9xuXQPVq7eFHQ78nq%2BAz3ibevxSV31429S8c5SRDLaDdoTiThRFVJdaVPqabIc5tMJGkprYGOrMBd5SrTh9xnBp%2F%2F1eDTpV%2FpCdR1Ur7pPlTfyGcXeRBsIiALf%2BUcGUj%2FMV8SI2wRL3BxEZsOxaOScLCJq7iwG%2BCsV4OABwDzOLNGz36%2Fvu28HKFRVaG6hJyJy579igxct%2BSneFTvrh9QlbxiKGZIib%2FjBzJp9Gpx4KsHxmBTrHt901dNhmV7CvSoR6FA4bWDGwsSZQ5Jm2qbvR5BVC4MdwcOtUIGhnlopDuLm44eT%2F8gE%2Fronc%3D&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20240824T084855Z&X-Amz-SignedHeaders=host&X-Amz-Expires=300&X-Amz-Credential=ASIAUPUUPRWE2KJYA23L%2F20240824%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Signature=1c882dc28dc7a72edd6336f8d6b538f6357867a5c8ad9edbb628c4792c939950) that uses the _ordinal rank_ of the rolling skew of the (log) returns of assets to assemble a self-financing portfolio. 

Skewness can be thought of as the (normalized) third moment of a distribution, that is, a measure of its _assymetry_. This trading strategy implicitly stipulates that long-term positive skews on the log-returns of assets (or at least well above current market medians) means that an asset is overvalued, and is thus more likely to lose value in the near future: thus, assets with larger, positive skews are assigned a negative weight in the portfolio and negative skew assets are assigned postive signs.

![AAPL_skew](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/AAPL_example_skew.png)

The definitions we use are:

Log returns are defined via:

$r_t = \log(S_t / S_{t-1})$

We may construct the _rolled_ skewness estimate from such a datavector: for each index $t$, we consider the last $L$ days (appr. 100-300) trading days' log returns as a sample and provide an estimate for the skewness. We stress that the _rolled quantities must strictly only access information from the past_ when backtesting! 

The strategy then proceeds as such: given some $N$ number of assets and a _assesment period_ of $T$, at the end of every period's closing moment, we calculate the current rolling skewness, and the new weights derived from it. _However_ we only update our weights the next day (as we are not able the same day/we would get a free day of 'informed' returns.

The actual portfolio weights are calculated via:

$ z*(O(\kappa)_i - (N+1)/2 )$

where $O()$ is the ordinal rank, $\kappa$ is the rolled skew at the assesment day, and z is chosen such that the sum of the total weights should be zero (ensuring self financing). For details see the `cross_skew.jl` file. Most of the data pipeline and its dynmically implemented supprt is found in `support_funcs.jl`

Bellow we present the results of the portfolio and its weight evolution. The data used for this backtest was pulled thru an AlpacaMarkets API, using data from 2016-2024 on commodities ("GLD", "SLV", "GSG", "USO", "PPLT", "UNG", "DBA"), but the actual backtest was run on a smaller period, allowing for a larger confidence on the rolling skew. 

Evolution of portfolio weights:

![p_comm_weights](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/commodities_weights.png)

Market (un-weighted) vs strategy cummultative log returns:

![market_v_portf](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/market_vs_skew_commodity.png) 

Relative closing price perfomance against initial values:

![norm_close_comm](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/commodities_norm_asset_perf.png)

After performing the backtest, we perform a simple linear regression between the market- and portfolio log returns, of the form of:

$r_p = \alpha + \beta * r_m$

From the above form, we get parameter values.

| Coefficients | Coef.      | Std. Error | t    | Pr(>|t|) | Lower 95%   | Upper 95%   |
|--------------|------------|------------|------|----------|-------------|-------------|
| **alpha**    | 0.000382148 | 0.000442704| 0.86 | 0.3881   | -0.000486095 | 0.00125039  |
| **beta**     | 0.225063   | 0.0406256  | 5.54 | <1e-07   | 0.145387    | 0.304739    |

I.e. while we technically have a non-zero alpha (even if just very small), its confidence interval is very large and it has a small t-score, indicating low confidence. A bit more troubling is that the $\beta$ is much different from 0, suggesting that we are not de-clupled from the market enough and is still suspicible to market movements. 

Parts of this part of the codebase (mainly the @groupby trick) was found by me while reading about this strategy, located [here](https://dm13450.github.io/2024/02/08/Cross-Asset-Skew-A-Trading-Strategy.html) where I also found out about GLM (with the added benefit that I can compare my parameters). All credit is due to the author.

