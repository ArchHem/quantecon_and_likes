module QSupport
using Dates, AlpacaMarkets, DataFrames, Statistics, DataFramesMeta

function QDateTime(date_string::AbstractString)
    init_date = DateTime(date_string, dateformat"yyyy-mm-ddTHH:MM:SSZ")
    
    return init_date
end

function STimeSeriesGen(id_string::AbstractString,startDate::DateTime,endDate::DateTime)
    df, name = AlpacaMarkets.stock_bars(id_string, "1Day", startTime = startDate,endTime = endDate, adjustment = "all", limit = 10000)
    

    df.t = QDateTime.(df[!,:t])

    to_keep = [:t, :c]

    select!(df,to_keep)
    
    return df
end

function log_return(prices::Vector{T}) where T<:Real
    
    log_returns = log.(prices[2:end] ./ prices[1:end-1])
    log_returns = vcat([zero(T)],log_returns)
    return log_returns
end

function trunc(x::Vector)
    return x[2:end]
end

function generate_col_names(df::DataFrame,column_basis::Symbol)
    #useful for selecting, say, all columns that start with c (closing price)
    col_names = names(df)
    correct_cols = filter(name -> startswith(string(name),string(column_basis)), col_names)
    correct_cols = Symbol.(correct_cols)
    return correct_cols
end

function portfolio_load(tickers::Vector{T}, startDate::DateTime,endDate::DateTime, windows_size::Integer = 100) where T<:AbstractString
    #prepares data for future weightning

    df_gl = STimeSeriesGen(tickers[1],startDate,endDate)
    rename!(df_gl, :c => Symbol("c_"*tickers[1]))
    
    for (index, tick) in enumerate(tickers[2:end])
        
        df_local = STimeSeriesGen(tick,startDate,endDate)
        
        rename!(df_local, :c => Symbol("c_"*tick))
        df_gl = innerjoin(df_gl,df_local, on = :t)
    end

    return df_gl

end

function floored_statistic(df::DataFrame,period::DatePeriod)
    #given some period, this function will generate  a new df that has the aggregate columns only, i.e. value of statistics at the floor-points of period
    #, furthermore adding a next-trade-day column_basis
    #we assume that the date/time column has symbol :t
    #if the next trading day is not known at the end of dates, we assume it to be the next day

    #time of assesing the portfolio...
    close_df = deepcopy(df)
    
    non_time_cols = Symbol.(names(close_df))
    
    filter!(e->e≠:t,non_time_cols)

    
    #time of re-arranging the portfolio
    next_df = DataFrame(t_next = [close_df[2:end,:t]; close_df[end,:t] + Day(1)], t = close_df[:,:t])


    for col in non_time_cols
        #not safe to use @views here
        next_df[!,col] = [close_df[2:end,col]; close_df[end,col]]
    end

    #perform flooring

    close_df = @transform(close_df,:period_start = floor.(:t, period))
    next_df = @transform(next_df,:period_start = floor.(:t, period))

    #metaprogramming-under-the-hood
    
    combine_pairs_close = [col => last => col for col in [:t; non_time_cols]]
    combine_pairs_next = [col => last => col for col in [:t; :t_next; non_time_cols]]
    

    #now, we re-construct the dataset using @combine, but such that we only retain information on the last-and-next trading days

    close_df = combine(groupby(close_df,:period_start), combine_pairs_close...)
    
    
    next_df = combine(groupby(next_df,:period_start), combine_pairs_next...)

    #we rename columns and bring to common convention

    select!(next_df,Not(:t))
    rename!(next_df,:t_next => :t)


    return close_df, next_df



end

function build_LR_df!(df::DataFrame)
    cost_colls = generate_col_names(df,:c)

    for name in cost_colls
        local_prices = df[!,name]
        local_log_returns = log_return(local_prices)
        local_col_name = Symbol("lr_"*String(name))
        
        df[!,local_col_name] = local_log_returns
    end
    return df
end

function build_rolling_df!(df::DataFrame, roll_func::Function,col_symbol::Symbol, window_size::T) where T<:Integer
    #given some starting symbol, this will calculate the rolling function, rolling_func's over all columns that are marked via col_symbol
    @assert window_size > one(T)
    columns_to = generate_col_names(df,col_symbol)
    func_name = String(Symbol(roll_func))
    for name in columns_to
        local_data = df[!,name]
        rolled_val = rolling_func(roll_func,local_data,window_size)

        local_col_name = Symbol("rolled_"*func_name*"_"*String(name))
        df[!,local_col_name] = rolled_val

    end
    return df
end

function rolling_func(func::Function,data::AbstractVector, windows_size::Integer)
    #given a function from R^n -» R this function calculates its (padded) time-series, shifted to the 'left' (no info about the future!)
    #we implicitly assume 1-based indexing: to fix, modify lower/upper index
    N = length(data)
    aggr = zeros(eltype(data),N)
    for i in eachindex(data)
        lower_index = maximum([i-windows_size,1])
        upper_index = minimum([i,N])
        local_ver = @views data[lower_index:upper_index]
        aggr[i] = func(local_ver)
    end
    return aggr
end

function skew(data::AbstractVector)
    N = length(data)
    mu = mean(data)
    T = eltype(data)
    sigma = N == 1 ? one(T) : std(data)
    result = mean(((data .- mu)./ sigma).^3)
    return result
end

export QDateTime, STimeSeriesGen, log_return, rolling_func, skew, portfolio_load, period_agregate, generate_col_names, build_LR_df!, build_rolling_df!, floored_statistic

end