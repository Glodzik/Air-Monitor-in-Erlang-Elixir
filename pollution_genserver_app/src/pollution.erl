%%%-------------------------------------------------------------------
%%% @author jakub
%%% @copyright (C) 2026, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. mar 2026 20:12
%%%-------------------------------------------------------------------
-module(pollution).
-author("jakub").

%% API
-export([
  create_monitor/0,
  add_station/3,
  add_value/5,
  remove_value/4,
  get_one_value/4,
  get_station_min/3,
  get_daily_mean/3,
  get_station_mean/3,
  get_maximum_gradient_stations/3
]).

-record(monitor, {stations=[]}).
-record(station, {name, coordinates, measurements=[]}).
-record(measurement, {datetime, type, value}).

create_monitor() -> #monitor{}.

station_exists(Name, Coordinates, Monitor) ->
  lists:any(
    fun(Station) ->
      Station#station.name == Name orelse
        Station#station.coordinates == Coordinates
    end
    , Monitor#monitor.stations).


add_station(Name, Coordinates, Monitor) ->
  case station_exists(Name, Coordinates, Monitor) of
    true -> {error, stationAlreadyExists};
    false ->
      NewStation = #station{name = Name, coordinates = Coordinates},
      Monitor#monitor{stations = [NewStation | Monitor#monitor.stations]}
  end.

measurement_exists(Station, DateTime, Type) ->
  lists:any(
    fun (Measurement) ->
      Measurement#measurement.datetime == DateTime andalso
        Measurement#measurement.type == Type
      end
    , Station#station.measurements).

get_station(NameOrCoords, Monitor) ->
  Stations = Monitor#monitor.stations,
  Found = case NameOrCoords of
    Name when is_list(Name) ->
      [Station || Station <- Stations, Station#station.name == Name];
    Coords when is_tuple(Coords) ->
      [Station || Station <- Stations, Station#station.coordinates == Coords];
    _ ->
      []
  end,
  case Found of
    [Station] -> Station;
    _ -> {error, notFound}
  end.

add_value(NameOrCoords, DateTime, Type, Value, Monitor) ->
  case get_station(NameOrCoords, Monitor) of
    {error, notFound} -> {error, stationNotFound};
    Station ->
      case measurement_exists(Station, DateTime, Type) of
        false ->
          OtherStations = [S || S <- Monitor#monitor.stations, S /= Station],
          NewMeasurement = #measurement{datetime = DateTime, type = Type, value = Value},
          NewMeasurements = [NewMeasurement | Station#station.measurements],
          NewStation = Station#station{measurements = NewMeasurements},
          Monitor#monitor{stations = [NewStation | OtherStations]};
        true -> {error, measurementAlreadyExists}
      end
  end.

remove_value(NameOrCoords, Datetime, Type, Monitor) ->
  case get_station(NameOrCoords, Monitor) of
    {error, notFound} -> {error, stationNotFound};
    Station ->
      case measurement_exists(Station, Datetime, Type) of
        false -> {error, noMeasurementFound};
        true ->
          OtherStations = [S || S <- Monitor#monitor.stations, S /= Station],
          NewMeasurements = [M || M <- Station#station.measurements,
            not (M#measurement.datetime == Datetime andalso M#measurement.type == Type) ],
          NewStation = Station#station{measurements = NewMeasurements},
          Monitor#monitor{stations = [NewStation | OtherStations]}
      end
  end.

get_one_value(NameOrCoords, Datetime, Type, Monitor) ->
  case get_station(NameOrCoords, Monitor) of
    {error, notFound} -> {error, stationNotFound};
    Station ->
      Measurements = Station#station.measurements,
      Found = [M || M <- Measurements,
        M#measurement.type == Type, M#measurement.datetime == Datetime],
      case Found of
        [Measurement] -> Measurement#measurement.value;
        _ -> {error, measurementNotFound}
      end
  end.

get_min_value([]) -> {error, noValues};
get_min_value(Values) ->
  FindMin = fun
              (X, Min) when X < Min -> X;
              (X, infinity) -> X;
              (_, Value) -> Value
            end,
  lists:foldl(FindMin, infinity, Values).

get_station_min(NameOrCoords, Type, Monitor) ->
  case get_station(NameOrCoords, Monitor) of
    {error, notFound} -> {error, stationNotFound};
    Station ->
      Measurements = Station#station.measurements,
      Values = [M#measurement.value || M <- Measurements, M#measurement.type == Type],
      case get_min_value(Values) of
        {error, noValues} -> {error, noMeasurementsFound};
        Min -> Min
      end
  end.

compare_dates(MeasurementDateTime, Date) ->
  {{YearM, MonthM, DayM}, _} = MeasurementDateTime,
  {Year, Month, Day} = Date,
  YearM == Year andalso MonthM == Month andalso DayM == Day.

calc_mean([]) -> {error, noValues};
calc_mean(Values) ->
  SumAndCount = fun
                  (X, {Sum, Count}) -> {Sum + X, Count + 1};
                  (_, V) -> V
                end,
  {Sum, Count} = lists:foldl(SumAndCount, {0, 0}, Values),
  Sum / Count.

get_daily_mean(Type, Date, Monitor) ->
  Values_From_Date = fun
                       (Station, Acc) ->
                         Values = [V#measurement.value || V <- Station#station.measurements,
                           V#measurement.type == Type,
                           compare_dates(V#measurement.datetime, Date)],
                         Acc ++ Values
                     end,
  AllValues = lists:foldl(Values_From_Date, [], Monitor#monitor.stations),
  case calc_mean(AllValues) of
    {error, noValues} -> {error, noMeasurementsFound};
    Mean -> Mean
  end.

get_station_mean(NameOrCoords, Type, Monitor) ->
  case get_station(NameOrCoords, Monitor) of
    {error, notFound} -> {error, stationNotFound};
    Station ->
      Measurements = Station#station.measurements,
      Values = [V#measurement.value || V <- Measurements, V#measurement.type == Type],
      case calc_mean(Values) of
        {error, noValues} -> {error, noMeasurementsFound};
        Mean -> Mean
      end
  end.

calc_distance(Coords1, Coords2) ->
  {X1, Y1} = Coords1,
  {X2, Y2} = Coords2,
  math:sqrt(math:pow(X2 - X1, 2) + math:pow(Y2 - Y1, 2)).

calc_gradient(Value1, Value2, Coords1, Coords2) ->
  abs(Value1 - Value2) / calc_distance(Coords1, Coords2).

get_max_gradient(StationsWithGradients) ->
  [FirstStation | OtherStations] = StationsWithGradients,
  FindMax = fun
              ({S1, S2, Grad}, {_, _, MaxGrad}) when Grad > MaxGrad -> {S1, S2, Grad};
              (_, {MaxS1, MaxS2, MaxGrad}) -> {MaxS1, MaxS2, MaxGrad}
            end,

  lists:foldl(FindMax, FirstStation, OtherStations).

get_maximum_gradient_stations(Type, Date, Monitor) ->
  StationsWithValues = [
      {S, M#measurement.value} ||
      S <- Monitor#monitor.stations,
      M <- S#station.measurements,
      M#measurement.type == Type,
      compare_dates(M#measurement.datetime, Date)
    ],

  case length(StationsWithValues) >= 2 of
    false -> {error, notEnoughStations};
    true ->
      StationsWithGradients = [
        {S1, S2, calc_gradient(Value1, Value2, S1#station.coordinates, S2#station.coordinates)} ||
        {S1, Value1} <- StationsWithValues,
        {S2, Value2} <- StationsWithValues,
        S1#station.name < S2#station.name
      ],
      {S1, S2, MaxGradient} = get_max_gradient(StationsWithGradients),
      {{S1#station.name, S1#station.coordinates}, {S2#station.name, S2#station.coordinates}, MaxGradient}
  end.
