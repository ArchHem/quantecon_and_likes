using CSV
include("../support/support_funcs.jl")
using DataFrames, Dates, Plots, StatsBase, ProgressBars, DataFramesMeta, GLM
using .QSupport

#import queried data

full_commodities = CSV.read("data/commodities_2016_2024.csv",DataFrame)
closing_commodities = CSV.read("data/commodities_2016_2024_close.csv",DataFrame)


#we want to begin from a date that is not at the very end of the stock histories... because we want good skew estimates!

const lower_date = Date(2017,1,1)
const higher_date = Date(2025,1,1)

function filter_df!(df::DataFrame, l_d::Date, h_d::Date)
    is_between(t) = (l_d <= t) & (h_d >= t)
    filter!(:t => is_between, df)
    return df
end

function skew_weights(rolled_skews::T) where T<:AbstractVector
    #based on the paper, eq. (2)
    N_assets = length(rolled_skews)
    mid_weights = ordinalrank(-1 .* rolled_skews) .- (N_assets+1) / 2
    #sum of short/long positions should sum to 0
    #given N assets, we will have n = floor(N/2) negative and positive signed assets... so their sum-of-groups will be n(n+1)/2
    n = floor(N_assets/2)
    actual_weights = mid_weights ./ (n*(n+1)/2)

    return actual_weights
end

function skew_based_trade(df::DataFrame, asses_df::DataFrame, colname_start::Symbol = :rolled_skew_lr_c)
    relevant_calls = generate_col_names(df,colname_start)
    number_of_assets = length(relevant_calls)

    #assumes we save log-returns as lr_c starting columns...
    
    #the way we implement is via:
    #at the end date of each period (stored in the closing dataframe) we asses the rolling skew and weight our portfolio according to it. 
    #The next trading day, we re-weight our portfolio and get the new returns according to it
    
    #first, we build our portfolio on the 1st day

    #next, we apply a cumsum operator until the next evaluation day, as weighted by the skew-incuded weights
    

    N_dates = length(df[!,:t])
    lr_history = zeros(Float64,(number_of_assets,N_dates))

    #to vectors
    skews = collect(df[1,relevant_calls])

    weights = skew_weights(skews)

    return_cols = generate_col_names(df,:lr_c)

    current_lr = collect(df[1,return_cols])

    weighted_returns = weights .* current_lr

    lr_history[:,1] = weighted_returns

    res_dates = length(asses_df[!,:t])
    weight_history = zeros(Float64,(number_of_assets,res_dates))
    weight_history[:,1] = weights
    
    asses_index = 1

    for j in 2:N_dates

        #if we have not passed an assesment day, dont switch up the weights...

        current_lr = collect(df[j,return_cols])

        weighted_returns = weights .* current_lr

        lr_history[:,j] = weighted_returns

        #we switch from next day onwards!
        if df[j,:t] >= asses_df[asses_index,:t]
            #even if we begin trading on an assesment day, this ensures correct behaviour!
            
            #re-evaluate weights - but only for next trading day!
            skews = collect(asses_df[asses_index,relevant_calls])
            weights = skew_weights(skews)
            weight_history[:,asses_index] = weights
            asses_index = asses_index + 1

        end
    end

    market_lr = Matrix(df[:,return_cols])

    return lr_history, market_lr, weight_history


end

function get_asset_name(x::String,p::String = "c_")
    l = length(p)
    actual = x[l+1:end]
    return actual
end


filter_df!(full_commodities, lower_date, higher_date)
filter_df!(closing_commodities, lower_date, higher_date)

asset_cols = String.(generate_col_names(full_commodities,:c_))
names = get_asset_name.(asset_cols)
N_assets = length(names)
m_names = reshape(names,1,:)
lr_hist, market_lr, weight_history = skew_based_trade(full_commodities,closing_commodities)

date_d = closing_commodities[!,:t]

#plot(date_d,transpose(weight_history), dpi = 1600, label = m_names, ls = :dot, title = "Portfolio weights", ylabel = "Normalized weights", lw = 2)

#cumsum-d LR's 



#we need the volatility for the next step.... luckily, we can construct it.
const volat_cost = 0.1

#construct the portfolio (weighted) log returns

port_returns = vcat(sum(lr_hist, dims = 1)...)
market_returns = vcat(mean(market_lr', dims = 1)...)

plot_t = full_commodities[!,:t]
#plot(plot_t, cumsum(port_returns), label = "Cummultative cross-skew portfolio log returns", ylabel = "∝ ∑ log(r)", title = "Market vs portfolio returns", dpi = 1500)
#plot!(plot_t, cumsum(market_returns), label = "Cummultative market log returns")

cols_to_plot = generate_col_names(full_commodities,:c_)

ydata = Matrix(full_commodities[!,cols_to_plot])
init_norm = ydata[1:1,:]

#plot(plot_t, ydata ./ init_norm,label = m_names, dpi = 1500, title = "Individual asset performances norm. ", 
#ylabel = "Init. norm. closing Price")

#now we get market beta and alpha (if any...)

fdata = DataFrame(X = market_returns, Y = port_returns)
params = lm(@formula(Y ~ X),fdata)
