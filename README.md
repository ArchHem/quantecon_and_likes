# quantecon_and_likes
Exercises/concepts I came across while studying the (julia) quantecon course/and or while reading John C. Hull's derivative book.

## Trading Strategies
### Ordinal Cross Asset Skew

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

### Non-ordinal cross asset skew

This section will examine if if its possible to use not just the ordinality, but the relative deviances of the assets to construct the weightnings and if its produces any (better) results. 

The basic idea is that, given some historic indicator of the _pivot_,$\rho(t)$, rolling skew (for skews above which we will construct negative weights) and the distances between this pivot and the individual asset rolling skews, $\rho(t) - \hat{S}(t)_i = d(t)_i$, it is possible to construct a portfolio that not just considers the ordinal rank of the assets, but their reltaive magnitudes as well. 

To provide a concrete example, the current median element of the assets can be used as a pivot elemens, and the weights can be proportional to $w(t)_i = d(t)_i^n$ where n > 0.0. Bellow we illustrate the median vs average rolling skew across our asset group, across some 20 equities. 

![med_vs_avg](https://github.com/ArchHem/quantecon_and_likes/blob/main/visul/Equities_med_vs_avg.png)

The following, intermediate results were produced on trading intervals of 1 month, rolling time windows of 200 trading days and the median of the current rolling skews as the pivot. We have used a portfolio of 40 stock indeces as a backtest. The GLM fit was carried out on the log-returns. (TBA: other asset classes)

We have found that while n>1.0 is typically able to beat the historical equity market using n > 1.0, the resulting GLM fit produces statistically insignificant $\alpha$/$\Beta$. For n<0.5, the significance results get _much_ better, with p-values well under 0.05, with annual $\alpha$ around 2.5-3.0%. The computation of Sharpe ratio is not yet carried out as AlpacaMarkets does not provide easily retrivable US treasy bond yields. However, for these parameter values we are actually beaten by the historic market. 
TBA: Plots




