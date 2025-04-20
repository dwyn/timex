defmodule Timex.Format.DateTime.Formatter do
  @moduledoc """
  This module defines the behaviour for custom DateTime formatters.
  """

  alias Timex.{Timezone, Translator, Types}
  alias Timex.Translator
  alias Timex.Format.FormatError
  alias Timex.Format.DateTime.Formatters.{Default, Strftime, Relative}
  alias Timex.Parse.DateTime.Tokenizers.Directive

  @callback tokenize(format_string :: String.t()) ::
              {:ok, [Directive.t()]} | {:error, term}
  @callback format(date :: Types.calendar_types(), format_string :: String.t()) ::
              {:ok, String.t()} | {:error, term}
  @callback format!(date :: Types.calendar_types(), format_string :: String.t()) ::
              String.t() | no_return
  @callback lformat(
              date :: Types.calendar_types(),
              format_string :: String.t(),
              locale :: String.t()
            ) ::
              {:ok, String.t()} | {:error, term}
  @callback lformat!(
              date :: Types.calendar_types(),
              format_string :: String.t(),
              locale :: String.t()
            ) ::
              String.t() | no_return

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Timex.Format.DateTime.Formatter

      alias Timex.Parse.DateTime.Tokenizers.Directive
      import Timex.Format.DateTime.Formatter, only: [format_token: 5, format_token: 6]
    end
  end

  @doc """
  Formats a Date, DateTime, or NaiveDateTime as a string, using the provided format string,
  locale, and formatter. If the locale does not have translations, "en" will be used by
  default.

  If a formatter is not provided, the formatter used is `Timex.Format.DateTime.Formatters.DefaultFormatter`

  If an error is encountered during formatting, `lformat!` will raise
  """
  @spec lformat!(Types.valid_datetime(), String.t(), String.t(), atom | nil) ::
          String.t() | no_return
  def lformat!(date, format_string, locale, formatter \ Default)

  def lformat!({:error, reason}, _format_string, _locale, _formatter),
    do: raise(ArgumentError, to_string(reason))

  def lformat!(date, format_string, locale, formatter) do
    with {:ok, formatted} <- lformat(date, format_string, locale, formatter) do
      formatted
    else
      {:error, :invalid_date} ->
        raise ArgumentError, "invalid_date"

      {:error, {:format, reason}} ->
        raise FormatError, message: to_string(reason)

      {:error, reason} ->
        raise FormatError, message: to_string(reason)
    end
  end

  @doc """
  Formats a Date, DateTime, or NaiveDateTime as a string, using the provided format string,
  locale, and formatter.

  If the locale provided does not have translations, "en" is used by default.

  If a formatter is not provided, the formatter used is `Timex.Format.DateTime.Formatters.DefaultFormatter`
  """
  @spec lformat(Types.valid_datetime(), String.t(), String.t(), atom | nil) ::
          {:ok, String.t()} | {:error, term}
  def lformat(date, format_string, locale, formatter \ Default)

  def lformat({:error, _} = err, _format_string, _locale, _formatter),
    do: err

  def lformat(datetime, format_string, locale, :strftime),
    do: lformat(datetime, format_string, locale, Strftime)

  def lformat(datetime, format_string, locale, :relative),
    do: lformat(datetime, format_string, locale, Relative)

  def lformat(%{__struct__: struct} = date, format_string, locale, formatter)
      when struct in [Date, DateTime, NaiveDateTime, Time] and is_binary(format_string) and
             is_binary(locale) and is_atom(formatter) do
    formatter.lformat(date, format_string, locale)
  end

  def lformat(date, format_string, locale, formatter)
      when is_binary(format_string) and is_binary(locale) and is_atom(formatter) do
    with %NaiveDateTime{} = datetime <- Timex.to_naive_datetime(date) do
      formatter.lformat(datetime, format_string, locale)
    end
  end

  @doc """
  Formats a Date, DateTime, or NaiveDateTime as a string, using the provided format
  string and formatter. If a formatter is not provided, the formatter
  used is `Timex.Format.DateTime.Formatters.DefaultFormatter`.

  Formatting will use the configured default locale, "en" if no other default is given.

  If an error is encountered during formatting, `format!` will raise.
  """
  @spec format!(Types.valid_datetime(), String.t(), atom | nil) :: String.t() | no_return
  def format!(date, format_string, formatter \ Default)

  def format!(date, format_string, formatter),
    do: lformat!(date, format_string, Translator.current_locale(), formatter)

  @doc """
  Formats a Date, DateTime, or NaiveDateTime as a string, using the provided format
  string and formatter. If a formatter is not provided, the formatter
  used is `Timex.Format.DateTime.Formatters.DefaultFormatter`.

  Formatting will use the configured default locale, "en" if no other default is given.
  """
  @spec format(Types.valid_datetime(), String.t(), atom | nil) ::
          {:ok, String.t()} | {:error, term}
  def format(date, format_string, formatter \ Default)

  def format(datetime, format_string, :strftime),
    do: lformat(datetime, format_string, Translator.current_locale(), Strftime)

  def format(datetime, format_string, :relative),
    do: lformat(datetime, format_string, Translator.current_locale(), Relative)

  def format(datetime, format_string, formatter),
    do: lformat(datetime, format_string, Translator.current_locale(), formatter)

  @doc """
  Validates the provided format string, using the provided formatter,
  or if none is provided, the default formatter. Returns `:ok` when valid,
  or `{:error, reason}` if not valid.
  """
  @spec validate(String.t(), atom | nil) :: :ok | {:error, term}
  def validate(format_string, formatter \ Default)

  def validate(format_string, formatter) when is_binary(format_string) and is_atom(formatter) do
    formatter =
      case formatter do
        :strftime -> Strftime
        :relative -> Relative
        _ -> formatter
      end

    case formatter.tokenize(format_string) do
      {:error, _} = error ->
        error

      {:ok, []} ->
        {:error, "There were no formatting directives in the provided string."}

      {:ok, directives} when is_list(directives) ->
        :ok
    end
  end

  # ... rest of format_token clauses unchanged ...

  defp pad_char(:zeroes), do: <<?0>>
  defp pad_char(:spaces), do: <<32>>

  # Updated width_spec to include explicit step
  defp width_spec(min..max//_), do: [min: min, max: max]
  defp width_spec(min, max),        do: [min: min, max: max]
end
