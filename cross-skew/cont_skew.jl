using CSV
include("../support/data_generation.jl")
using DataFrames, Dates, Plots, StatsBase, ProgressBars, DataFramesMeta, GLM
using Distributions, Plots


#generate data on spot


const start_date_l = DateTime(2015,1,1)
const ending_date_l = DateTime(2024,7,1)

const portfolio_vec = ["SPY", "EWU", "EWJ", "INDA", "EWG", "EWL", "EWP", "EWQ", 
"VTI", "FXI", "EWZ", "EWY", "EWA", "EWC", 
"EWH", "EWI", "EWN", "EWD", "EWT", "EZA", "EWW", "ENOR", "EDEN", "TUR", #originals
"DIA", "QQQ", "IWM", "MDY", "IVV", "XLF", "XLK", "XLV", 
"XLY", "XLE", "VEA", "EEM", "IEFA", "AAXJ", "EPI", 
"FM", "ICLN", "IGF", "SCHX", "VUG", "VTV", "IJR", "VT", "EWGS" #expanded
]

portfolio = portfolio_load(portfolio_vec, start_date_l,ending_date_l)



portfolio = build_LR_df!(portfolio)
portfolio = build_rolling_df!(portfolio,skew,:lr,200)


col_analysis = generate_col_names(portfolio,:rolled_skew)

an_start = DateTime(2017,1,1)
#use filter next time, safer
portfolio = portfolio[portfolio[!,:t] .> an_start,:]
subset = @views portfolio
lr_skews = subset[!,[:t, col_analysis...]]
plotdates = subset[!,:t]
plotlabels = reshape(portfolio_vec,1,length(portfolio_vec))

skews = Matrix(subset[!, col_analysis])

mus = mean(skews, dims = 2)
rhos = std(skews, dims = 2)
medians = median(skews, dims = 2)

portfolio[!,:skew_avg] = [mus...]
portfolio[!,:skew_median] = [medians...]
close_df, next_df = floored_statistic(portfolio,Month(1))

function cont_skew_weights(rolled_skews, target, power = 0.2)
    norm = 0.5 #can technically be anything
    T = eltype(rolled_skews)
    weights = zeros(T, length(rolled_skews))
    
    dist = rolled_skews .- target
    pos_id = dist .> zero(T)
    neg_id = dist .< zero(T)
    
    weights[pos_id] .= @. abs(dist[pos_id])^power
    weights[pos_id] ./= sum(weights[pos_id])/norm
    weights[pos_id] .*= -1.0
    weights[neg_id] .= @. abs(dist[neg_id])^power
    weights[neg_id] ./= sum(weights[neg_id])/norm
    #positive skews get negative weights
    #this ensures the sum of weights remains 0
    
    return weights
end

function cont_skew_based_trade(df::DataFrame, asses_df::DataFrame, colname_start::Symbol = :rolled_skew_lr_c, target_call = :skew_median)
    relevant_calls = generate_col_names(df,colname_start)
    number_of_assets = length(relevant_calls)
    

    N_dates = length(df[!,:t])
    lr_history = zeros(Float64,(number_of_assets,N_dates))

    #to vectors
    skews = collect(df[1,relevant_calls])
    ltarget = df[1,target_call]

    weights = cont_skew_weights(skews,ltarget)

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
            ltarget = collect(asses_df[asses_index,target_call])
            weights = cont_skew_weights(skews,ltarget)
            weight_history[:,asses_index] = weights
            asses_index = asses_index + 1

        end
    end

    market_lr = Matrix(df[:,return_cols])

    return lr_history, market_lr, weight_history


end

lr_hist, market_lr, weight_history = cont_skew_based_trade(portfolio, close_df)

date_d = close_df[!,:t]

port_returns = vcat(sum(lr_hist, dims = 1)...)
market_returns = vcat(mean(market_lr', dims = 1)...)

plot_t = portfolio[!,:t]
plt = plot(plot_t, cumsum(port_returns), label = "Cummultative avg-cross-skew portfolio log returns", ylabel = "∝ ∑ log(r)", title = "Market vs portfolio returns", dpi = 1500)
plot!(plot_t, cumsum(market_returns), label = "Cummultative market log returns")

cols_to_plot = generate_col_names(portfolio,:c_)

ydata = Matrix(portfolio[!,cols_to_plot])
init_norm = ydata[1:1,:]

#plot(plot_t, ydata ./ init_norm,label = m_names, dpi = 1500, title = "Individual asset performances norm. ", 
#ylabel = "Init. norm. closing Price")

#now we get market beta and alpha (if any...)

fdata = DataFrame(X = market_returns, Y = port_returns)
params = lm(@formula(Y ~ X),fdata)