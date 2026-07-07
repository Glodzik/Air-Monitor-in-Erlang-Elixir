defmodule Pollutiondb.Reading do
  use Ecto.Schema
  import Ecto.Changeset
  require Ecto.Query

  schema "readings" do
    field :date, :date
    field :time, :time
    field :type, :string
    field :value, :float
    belongs_to :station, Pollutiondb.Station
  end

  defp changeset(reading, attrs) do
    reading
    |> Ecto.Changeset.cast(attrs, [:date, :time, :type, :value, :station_id])
    |> Ecto.Changeset.validate_required([:date, :time, :type, :value, :station_id])
    |> unique_constraint([:station_id, :date, :time, :type], name: :readings_station_id_date_time_type_index)
  end

  def add_now(station, type, value) do
    %Pollutiondb.Reading{}
    |> changeset(%{
        date: Date.utc_today(), time: Time.utc_now(), type: type, value: value, station_id: station.id
      })
    |> Pollutiondb.Repo.insert()
  end

  def add(station, date, time, type, value) do
    %Pollutiondb.Reading{}
    |> changeset(%{
      date: date, time: time, type: type, value: value, station_id: station.id
    })
    |> Pollutiondb.Repo.insert()
  end

  def find_by_date(year, month, day) do
    date = Date.new!(year, month, day)
    Ecto.Query.from(r in Pollutiondb.Reading,
      where: r.date == ^date,
      preload: [:station]
    )
    |> Pollutiondb.Repo.all
  end

end