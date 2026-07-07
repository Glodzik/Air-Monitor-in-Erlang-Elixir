%%%-------------------------------------------------------------------
%%% @author jakub
%%% @copyright (C) 2026, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 14. kwi 2026 18:14
%%%-------------------------------------------------------------------
-module(pollution_value_collector_gen_statem).
-author("jakub").

-behaviour(gen_statem).

%% API
-export([start_link/0, stop/0, set_station/1, add_value/3, store_data/0, callback_mode/0]).

%% gen_statem callbacks
-export([init/1, terminate/3, station/3, value/3]).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
  gen_statem:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() -> gen_statem:stop(?MODULE).

set_station(Station) ->
    gen_statem:cast(?MODULE, {set_station, Station}).

add_value(DateTime, Type, Value) ->
    gen_statem:cast(?MODULE, {add_value, {DateTime, Type, Value}}).

store_data() ->
    gen_statem:cast(?MODULE, store_data).

%%%===================================================================
%%% gen_statem callbacks
%%%===================================================================

init([]) ->
  {ok, station, []}.

station(_Event, {set_station, Station}, _) -> {next_state, value, {Station, []}}.

value(_Event, {add_value, Value}, {Station, Values}) -> {next_state, value, {Station, Values ++ [Value]}};

value(_Event, store_data, {Station, Values}) ->
    [pollution_gen_server:add_value(Station, DateTime, Type, Value)
        || {DateTime, Type, Value} <- Values],
    {next_state, station, []}.


terminate(_Reason, _StateName, _State) ->
  ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

callback_mode() -> state_functions.