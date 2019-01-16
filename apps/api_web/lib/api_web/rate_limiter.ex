defmodule ApiWeb.RateLimiter do
  @moduledoc """
  Tracks user requests for rate limiting.

  The rate limiter server counts the number of requests a given user has made
  within a given interval. An error is returned for a user if they attempt to
  make a request after they've reached their allotted request amount.
  """
  @limiter ApiWeb.config(:rate_limiter, :limiter)
  @clear_interval ApiWeb.config(:rate_limiter, :clear_interval)
  @intervals_per_day div(86_400_000, @clear_interval)
  @max_anon_per_interval ApiWeb.config(:rate_limiter, :max_anon_per_interval)
  @max_registered_per_interval ApiWeb.config(:rate_limiter, :max_registered_per_interval)

  ## Client

  def start_link(_opts \\ []) do
    @limiter.start_link(clear_interval: @clear_interval)
  end

  @doc """
  Logs that the user is making a resource to a given resource. If the user
  has already reached their allotted request amount, an error tuple is returned.

  Requests are counted in #{@intervals_per_day} #{@clear_interval}ms intervals per day.  The max requests per user
  per interval vary based on the type of user and whether they have requested a limit increase.

  | `ApiWeb.User` `type` | Requests Tracked By | `ApiWeb.User.t` `limit` | Max Requests Per Interval            |
  |-------------------|---------------------|----------------------|--------------------------------------|
  | `:anon`           | IP Address          | `nil`                | `#{@max_anon_per_interval}`          |
  | `:registered`     | `ApiWeb.User.t` `id`   | `nil`                | `#{
    @max_registered_per_interval
  }`    |
  | `:registered`     | `ApiWeb.User.t` `id`   | integer              | `user.limit / #{
    @intervals_per_day
  }` |
  """
  @spec log_request(any, String.t()) :: :ok | {:error, :rate_limited}
  def log_request(_, "/_health" <> _), do: :ok

  def log_request(user, _request_path) do
    max = max_requests(user)

    if @limiter.rate_limited?(user.id, max) do
      {:error, :rate_limited}
    else
      :ok
    end
  end

  @doc false
  def clear_interval, do: @clear_interval

  @doc false
  def intervals_per_day, do: @intervals_per_day

  if Mix.env() == :test do
    @doc "Helper function for testing, to clear the limiter state."
    def force_clear do
      @limiter.clear()
    end

    @doc "Helper function for testing, to list the active IDs."
    def list do
      @limiter.list()
    end
  end

  @doc false
  def max_anon_per_interval, do: @max_anon_per_interval

  @doc false
  def max_registered_per_interval, do: @max_registered_per_interval

  @doc """
  Returns the maximum number of requests a key can make over the interval.
  """
  @spec max_requests(ApiWeb.User.t()) :: non_neg_integer
  def max_requests(%ApiWeb.User{type: :anon}) do
    @max_anon_per_interval
  end

  def max_requests(%ApiWeb.User{type: :registered, limit: nil}) do
    @max_registered_per_interval
  end

  def max_requests(%ApiWeb.User{type: :registered, limit: daily_limit}) do
    div(daily_limit, @intervals_per_day)
  end
end
