defmodule Pollutiondb.PollutionDataLoader do
  def load_data(limit) do
    dataPath = "data\\AirlyData-ALL-50k.csv"
    data = dataPath
           |> File.stream!()
           |> Stream.take(limit)
           |> Enum.map(fn line -> parseline(String.trim(line)) end)

    add_stations(data)
    add_measurements(data)
  end

  defp parsedate(datetime) do
    [date, time] = datetime |> String.split("T")
    [year, month, day] = date |> String.split("-")
                         |> Enum.map(fn x -> t = Integer.parse(x); elem(t, 0) end)
    [hour, minute, second] = time |> String.split(":")
                             |> Enum.map(fn x -> t = Integer.parse(x); elem(t, 0) end)
    {{year, month, day}, {hour, minute, second}}
  end

  defp parseline(line) do
    [datetime, type, value, id, name, coords] = line |> String.split(";")
    [lon, lat] = coords
                 |> String.split(",")
                 |> Enum.map(fn x -> t = Float.parse(x); elem(t, 0) end)
    {{year, month, day}, {hour, minute, second}} = parsedate(datetime)
    date = Date.new!(year, month, day)
    time = Time.new!(hour, minute, second)
    station_id = elem(Integer.parse(id), 0)
    value_float = elem(Float.parse(value), 0)

    %{
      :date => date,
      :time => time,
      :type => type,
      :value => value_float,
      :station_id => station_id,
      :station_name => name,
      :lon => lon,
      :lat => lat
    }
  end

  defp add_stations(data) do
    data
    |> Enum.uniq_by(fn x -> x.station_id end)
    |> Enum.each(fn s -> Pollutiondb.Station.add("#{s.station_id} #{s.station_name}", s.lon, s.lat) end)
  end

  defp add_measurements(data) do
    data
    |> Enum.each(fn m ->
      stations = Pollutiondb.Station.find_by_location(m.lon, m.lat)
      case stations do
        [] -> IO.puts("Nie znaleziono stacji dla: #{m.station_id}")
        [station | _] -> Pollutiondb.Reading.add(station, m.date, m.time, m.type, m.value)
      end
    end)
  end
end