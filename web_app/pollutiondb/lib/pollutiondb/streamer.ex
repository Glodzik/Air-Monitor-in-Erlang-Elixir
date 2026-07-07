defmodule Pollutiondb.Streamer do
  use GenServer
  import Ecto.Query

  alias Pollutiondb.{Reading, Repo, Station, Loader}

  @topic "readings"
  @tick_ms 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def topic, do: @topic

  def current_station, do: GenServer.call(__MODULE__, :current_station)

  def set_station(station_id) when is_integer(station_id) do
    GenServer.cast(__MODULE__, {:set_station, station_id})
  end

  @impl true
  def init(:ok) do
    ensure_data_loaded()
    station = Repo.one(from s in Station, order_by: s.id, limit: 1)
    schedule_tick()
    {:ok, %{station_id: station && station.id, cursor: nil}}
  end

  @impl true
  def handle_call(:current_station, _from, state) do
    {:reply, state.station_id, state}
  end

  @impl true
  def handle_cast({:set_station, station_id}, state) do
    Phoenix.PubSub.broadcast(Pollutiondb.PubSub, @topic, {:station_changed, station_id})
    {:noreply, %{state | station_id: station_id, cursor: nil}}
  end

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()

    if state.station_id do
      case next_datetime(state.station_id, state.cursor) do
        {date, time} ->
          readings = readings_at(state.station_id, date, time)
          {:ok, datetime} = NaiveDateTime.new(date, time)
          Phoenix.PubSub.broadcast(Pollutiondb.PubSub, @topic, {:batch, datetime, readings})
          {:noreply, %{state | cursor: {date, time}}}
        nil ->
          {:noreply, %{state | cursor: nil}}
      end
    else
      {:noreply, state}
    end
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)

  defp ensure_data_loaded do
    if Repo.aggregate(Reading, :count, :id) == 0 do
      Pollutiondb.PollutionDataLoader.load_data(1000)
    end
  end

  defp next_datetime(station_id, nil) do
    query = from r in Reading,
                 where: r.station_id == ^station_id,
                 order_by: [asc: r.date, asc: r.time],
                 select: {r.date, r.time},
                 limit: 1
    Repo.one(query)
  end

  defp next_datetime(station_id, {current_date, current_time}) do
    query = from r in Reading,
                 where: r.station_id == ^station_id and (r.date > ^current_date or (r.date == ^current_date and r.time > ^current_time)),
                 order_by: [asc: r.date, asc: r.time],
                 select: {r.date, r.time},
                 limit: 1

    case Repo.one(query) do
      nil -> nil
      result -> result
    end
  end

  defp readings_at(station_id, date, time) do
    query = from r in Reading,
                 where: r.station_id == ^station_id and r.date == ^date and r.time == ^time
    Repo.all(query)
  end
end