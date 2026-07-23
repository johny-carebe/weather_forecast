defmodule WeatherForecast.Presentation.CLI do
  @moduledoc """
  Formats the forecast report and prints it to stdout.

  Owns all presentation concerns: the core returns full-precision
  floats and tagged errors; this module renders one decimal and
  human-readable failure reasons.
  """

  alias WeatherForecast.Application.Factories.CityResult
  alias WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures
  alias WeatherForecast.Domain.City

  @spec run() :: :ok
  def run do
    CalculateAverageMaxTemperatures.call()
    |> Enum.each(&IO.puts(format_line(&1)))
  end

  @spec format_line(CityResult.t()) :: String.t()
  def format_line({%City{name: name}, {:ok, average}}) do
    "#{name}: #{format_temperature(average)}°C"
  end

  def format_line({%City{name: name}, {:error, reason}}) do
    "#{name}: unavailable (#{format_reason(reason)})"
  end

  defp format_temperature(average) do
    case :erlang.float_to_binary(average, decimals: 1) do
      "-0.0" -> "0.0"
      formatted -> formatted
    end
  end

  defp format_reason({:api_error, message}), do: message
  defp format_reason({:http_status, status}), do: "HTTP #{status}"
  defp format_reason({:request_failed, message}), do: message
  defp format_reason(:malformed_response), do: "malformed response"
  defp format_reason(:timeout), do: "timeout"
  defp format_reason(other), do: inspect(other)
end
