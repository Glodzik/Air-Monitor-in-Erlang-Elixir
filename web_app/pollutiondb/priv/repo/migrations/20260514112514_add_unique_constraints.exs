defmodule Pollutiondb.Repo.Migrations.AddUniqueConstraints do
  use Ecto.Migration

  def change do
    create unique_index(:stations, [:name])
    create unique_index(:stations, [:lon, :lat])
    create unique_index(:readings, [:station_id, :date, :time, :type])
  end
end
