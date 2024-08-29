# quantecon_and_likes
Exercises/concepts I came across while studying the (julia) quantecon course/and or while reading John C. Hull's derivative book.

## Trading Strategies
### Cross Asset Skew

Corss asset skew trading refers to a trading strategy (see: [paper](https://www.pm-research.com/content/iijpormgmt/48/4/194) that uses the _ordinal rank_ of the rolling skew of the (log) returns of assets to assemble a self-financing portfolio. 

Skewness can be thought of as the (normalized) third moment of a distribution, that is, a measure of its _asymetry_. This trading strategy implicitly stipulates that long-term positive skews on the log-returns of assets (or at least well above current market medians) means that an asset is overvalued, and is thus more likely to lose value in the near future: thus, assets with larger, positive skews are assigned a negative weight in the portfolio and negative skew assets are assigned postive signs.

![AAPL_skew](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/AAPL_example_skew.png)

The definitions we use are:

Log returns are defined via:

$r_t = \log(S_t / S_{t-1})$

We may construct the _rolled_ skewness estimate from such a datavector: for each index $t$, we consider the last $L$ days (appr. 100-300) trading days' log returns as a sample and provide an estimate for the skewness. We stress that the _rolled quantities must strictly only access information from the past_ when backtesting! 

The strategy then proceeds as such: given some $N$ number of assets and a _assesment period_ of $T$, at the end of every period's closing moment, we calculate the current rolling skewness, and the new weights derived from it. _However_ we only update our weights the next day (as we are not able the same day/we would get a free day of 'informed' returns.

The actual portfolio weights are calculated via:

$z*(O(-\kappa)_i - (N+1)/2 )$

where $O()$ is the ordinal rank of the skew vector, $\kappa$ is the rolled skew at the assesment day, and z is chosen such that the sum of the total weights should be zero (ensuring self financing). For details see the `cross_skew.jl` file. Most of the data pipeline and its dynmically implemented supprt is found in `support_funcs.jl`

Bellow we present the results of the portfolio and its weight evolution. The data used for this backtest was pulled thru an AlpacaMarkets API, using data from 2016-2024 on commodities ("GLD", "SLV", "GSG", "USO", "PPLT", "UNG", "DBA"), but the actual backtest was run on a smaller period, allowing for a larger confidence on the rolling skew. 

Evolution of portfolio weights:

![p_comm_weights](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/commodities_weights.png)

Market (un-weighted) vs strategy cummultative log returns:

![market_v_portf](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/market_vs_skew_commodity.png) 

Relative closing price perfomance against initial values:

![norm_close_comm](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/commodities_norm_asset_perf.png)

After performing the backtest, we perform a simple linear regression between the market- and portfolio log returns, of the form of:

$r_p = \alpha + \beta * r_m$

From the above form, we get parameter values for the commodities asset group:

![comm_fit](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/commodity_fit.png)

I.e. we technically have a non-zero alpha (even if just very small), its confidence interval is very large and it has a small t-score, indicating low confidence. A bit more troubling is that the $\beta$ is much different from 0, suggesting that we are not de-clupled from the market enough and is still suspicible to market movements, further worsened by the fact that beta's parameter fit has a high confidence via t-test. 

For equities, we get a much 'better' fit:

![eq_fit](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/equities_fix.png)

The $\beta$ is much smaller in magnitude (we have succesfully de-coupled from the market) and we have some small, but much more confident positive alpha. As expected, the skewed portfolio still outperforms the unweighted market, but as easily seen, it has successfully avoided the worst of the market crashes as well.

![eq_perf](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/market_vs_skew_equities.png)




Parts of this part of the codebase (mainly the @groupby trick) was found by me while reading about this strategy, located [here](https://dm13450.github.io/2024/02/08/Cross-Asset-Skew-A-Trading-Strategy.html) where I also found out about GLM (with the added benefit that I can compare my parameters). All credit is due to the author.

