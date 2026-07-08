%%%-------------------------------------------------------------------
%%% @author jakub
%%% @copyright (C) 2026, <COMPANY>
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(pollution_gen_server).

-behaviour(gen_server).

-export([
  start_link/0,
  add_station/2,
  add_value/4,
  remove_value/3,
  get_one_value/3,
  get_station_min/2,
  get_daily_mean/2,
  get_station_mean/2,
  get_maximum_gradient_stations/2,
  crash/0
]).

-export([init/1, handle_call/3, terminate/2, handle_cast/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, pollution:create_monitor(), []).

init(InitialValue) ->
  {ok, InitialValue}.

%% ============= API =============

crash() -> gen_server:call(?MODULE, crash).

add_station(Name, Coordinates) ->
  gen_server:call(?MODULE, {add_station, Name, Coordinates}).

add_value(NameOrCoords, DateTime, Type, Value) ->
  gen_server:call(?MODULE, {add_value, NameOrCoords, DateTime, Type, Value}).

remove_value(NameOrCoords, Datetime, Type) ->
  gen_server:call(?MODULE, {remove_value, NameOrCoords, Datetime, Type}).

get_one_value(NameOrCoords, Datetime, Type) ->
  gen_server:call(?MODULE, {get_one_value, NameOrCoords, Datetime, Type}).

get_station_min(NameOrCoords, Type) ->
  gen_server:call(?MODULE, {get_station_min, NameOrCoords, Type}).

get_daily_mean(Type, Date) ->
  gen_server:call(?MODULE, {get_daily_mean, Type, Date}).

get_station_mean(NameOrCoords, Type) ->
  gen_server:call(?MODULE, {get_station_mean, NameOrCoords, Type}).

get_maximum_gradient_stations(Type, Date) ->
  gen_server:call(?MODULE, {get_maximum_gradient_stations, Type, Date}).

%% ============= HANDLERS =============

handle_call(crash, _From, State) -> {reply, crashed, State};

handle_call({add_station, Name, Coordinates}, _From, State) ->
  case pollution:add_station(Name, Coordinates, State) of
    {error, Message} -> {reply, {error, Message}, State};
    NewState -> {reply, ok, NewState}
  end;

handle_call({add_value, NameOrCoords, DateTime, Type, Value}, _From, State) ->
  case pollution:add_value(NameOrCoords, DateTime, Type, Value, State) of
    {error, Message} -> {reply, {error, Message}, State};
    NewState -> {reply, ok, NewState}
  end;

handle_call({remove_value, NameOrCoords, Datetime, Type}, _From, State) ->
  case pollution:remove_value(NameOrCoords, Datetime, Type, State) of
    {error, Message} -> {reply, {error, Message}, State};
    NewState -> {reply, ok, NewState}
  end;

handle_call({get_one_value, NameOrCoords, Datetime, Type}, _From, State) ->
  case pollution:get_one_value(NameOrCoords, Datetime, Type, State) of
    {error, Message} -> {reply, {error, Message}, State};
    Value -> {reply, Value, State}
  end;

handle_call({get_station_min, NameOrCoords, Type}, _From, State) ->
  case pollution:get_station_min(NameOrCoords, Type, State) of
    {error, Message} -> {reply, {error, Message}, State};
    Value -> {reply, Value, State}
  end;

handle_call({get_daily_mean, Type, Date}, _From, State) ->
  case pollution:get_daily_mean(Type, Date, State) of
    {error, Message} -> {reply, {error, Message}, State};
    Value -> {reply, Value, State}
  end;

handle_call({get_station_mean, NameOrCoords, Type}, _From, State) ->
  case pollution:get_station_mean(NameOrCoords, Type, State) of
    {error, Message} -> {reply, {error, Message}, State};
    Value -> {reply, Value, State}
  end;

handle_call({get_maximum_gradient_stations, Type, Date}, _From, State) ->
  case pollution:get_maximum_gradient_stations(Type, Date, State) of
    {error, Message} -> {reply, {error, Message}, State};
    Value -> {reply, Value, State}
  end.


handle_cast(_Request, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.