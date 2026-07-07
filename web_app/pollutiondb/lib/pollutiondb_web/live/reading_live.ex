defmodule PollutiondbWeb.ReadingLive do
  use PollutiondbWeb, :live_view

  alias Pollutiondb.Streamer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pollutiondb.PubSub, Streamer.topic())
    end

    stations = Pollutiondb.Station.get_all()
    current_station_id = Streamer.current_station()

    {:ok,
      socket
      |> assign(
           stations: stations,
           station_id: current_station_id,
           current_datetime: nil,
           latest: []
         )
      |> stream(:log, [])}
  end

  @impl true
  def handle_event("select_station", %{"station_id" => id_str}, socket) do
    station_id = String.to_integer(id_str)
    Streamer.set_station(station_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:station_changed, station_id}, socket) do
    socket =
      socket
      |> assign(
           station_id: station_id,
           current_datetime: nil,
           latest: []
         )
      |> stream(:log, [], reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:batch, datetime, readings}, socket) do
    socket =
      Enum.reduce(readings, socket, fn r, acc ->
        stream_insert(
          acc,
          :log,
          %{id: "r-#{r.id}", type: r.type, value: r.value, datetime: datetime},
          at: 0
        )
      end)

    {:noreply, assign(socket, current_datetime: datetime, latest: readings)}
  end

  defp bar_width(type, value) do
    max_val = max_value(type)
    percentage = (value / max_val) * 100
    min(percentage, 100.0)
  end

  defp max_value("PM10"), do: 200.0
  defp max_value("PM25"), do: 150.0
  defp max_value("PM1"), do: 100.0
  defp max_value("PRESSURE"), do: 1100.0
  defp max_value("HUMIDITY"), do: 100.0
  defp max_value("TEMPERATURE"), do: 50.0
  defp max_value(_), do: 100.0

  defp bar_color("PM10"), do: "bg-rose-500"
  defp bar_color("PM25"), do: "bg-orange-500"
  defp bar_color("PM1"), do: "bg-amber-500"
  defp bar_color("PRESSURE"), do: "bg-blue-500"
  defp bar_color("HUMIDITY"), do: "bg-cyan-500"
  defp bar_color("TEMPERATURE"), do: "bg-emerald-500"
  defp bar_color(_), do: "bg-zinc-500"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">

      <div class="mb-6 bg-white p-4 shadow-sm border border-zinc-200 rounded-lg">
        <form phx-change="select_station" class="flex items-center gap-4">
          <label class="font-medium text-zinc-700">Wybierz stację:</label>
          <select name="station_id" class="border border-zinc-300 rounded px-3 py-2 text-zinc-700 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500">
            <option :for={s <- @stations} value={s.id} selected={s.id == @station_id}>
              <%= s.name %>
            </option>
          </select>
        </form>
      </div>

      <h1 class="text-3xl font-bold mb-6 text-zinc-800">
        Paczka danych:
        <span class="text-blue-600">
          <%= if @current_datetime, do: @current_datetime, else: "Oczekiwanie na dane..." %>
        </span>
      </h1>

      <div class="space-y-2 mb-10 bg-white p-6 shadow-sm border border-zinc-200 rounded-lg">
        <h2 class="text-lg font-semibold mb-4 text-zinc-700">Aktualne wartości</h2>
        <%= for r <- @latest do %>
          <div class="flex items-center gap-3">
            <div class="w-24 text-xs font-mono text-zinc-600 font-bold"><%= r.type %></div>
            <div class="flex-1 bg-zinc-100 rounded h-6 overflow-hidden">
              <div
                class={"h-full transition-all duration-700 ease-out #{bar_color(r.type)}"}
                style={"width: #{bar_width(r.type, r.value)}%"}
              ></div>
            </div>
            <div class="w-20 text-right font-mono text-sm text-zinc-700">
              <%= :erlang.float_to_binary(r.value * 1.0, decimals: 2) %>
            </div>
          </div>
        <% end %>
      </div>

      <div class="bg-white shadow-sm border border-zinc-200 rounded-lg overflow-hidden">
        <div class="bg-zinc-50 px-6 py-3 border-b border-zinc-200">
          <h2 class="text-lg font-semibold text-zinc-700">Strumień odczytów (Log)</h2>
        </div>
        <div class="max-h-96 overflow-y-auto">
          <table class="min-w-full text-left text-sm whitespace-nowrap">
            <thead class="sticky top-0 bg-zinc-100 text-zinc-600">
              <tr>
                <th class="px-6 py-2 font-medium">Typ</th>
                <th class="px-6 py-2 font-medium">Wartość</th>
                <th class="px-6 py-2 font-medium">Data i Czas</th>
              </tr>
            </thead>
            <tbody id="log" phx-update="stream" class="divide-y divide-zinc-100">
              <tr :for={{dom_id, entry} <- @streams.log} id={dom_id} class="hover:bg-zinc-50">
                <td class="px-6 py-2 font-mono text-zinc-800"><%= entry.type %></td>
                <td class="px-6 py-2 font-mono text-zinc-800">
                  <%= :erlang.float_to_binary(entry.value * 1.0, decimals: 2) %>
                </td>
                <td class="px-6 py-2 text-zinc-500"><%= entry.datetime %></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end