defmodule ApiWeb.RateLimiterTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias ApiWeb.RateLimiter

  defp anon_user(id), do: %ApiWeb.User{type: :anon, id: id}
  defp user(id), do: %ApiWeb.User{type: :registered, id: id}

  defp wait_for_clear do
    clear_interval = ApiWeb.config(:rate_limiter, :clear_interval)
    :timer.sleep(trunc(clear_interval * 1.5))
  end

  setup do
    RateLimiter.force_clear()
  end

  test "start_link/1" do
    Application.stop(:api_web)

    on_exit(fn ->
      Application.start(:api_web)
    end)

    assert {:ok, _pid} = RateLimiter.start_link()
    refute :ets.info(:mbta_api_rate_limiter) == :undefined
  end

  test "max_requests/1" do
    assert RateLimiter.max_requests(%ApiWeb.User{type: :anon}) ==
             ApiWeb.config(:rate_limiter, :max_anon_per_interval)

    assert RateLimiter.max_requests(%ApiWeb.User{type: :registered}) ==
             ApiWeb.config(:rate_limiter, :max_registered_per_interval)

    assert RateLimiter.max_requests(%ApiWeb.User{type: :registered, limit: 864_000}) == 1
  end

  test "log_request rate limits anon users" do
    registered_user = user("user1")
    anon = anon_user("anon1")
    anon2 = anon_user("anon2")

    for _ <- 1..ApiWeb.config(:rate_limiter, :max_anon_per_interval) do
      assert :ok = RateLimiter.log_request(anon, "/foo")
      assert :ok = RateLimiter.log_request(registered_user, "/foo")
    end

    assert {:error, :rate_limited} = RateLimiter.log_request(anon, "/foo")
    assert :ok = RateLimiter.log_request(registered_user, "/foo")
    assert :ok = RateLimiter.log_request(anon2, "/foo")
    wait_for_clear()
    assert :ok = RateLimiter.log_request(anon, "/foo")
  end

  test "clears the table periodically" do
    registered_user = user("user1")

    for _ <- 1..10 do
      RateLimiter.log_request(registered_user, "/foo")
    end

    refute RateLimiter.list() == []
    wait_for_clear()
    assert RateLimiter.list() == []
  end

  test "excludes requests hitting `/_health" do
    registered_user = user("user1")
    RateLimiter.log_request(registered_user, "/_health")
    assert RateLimiter.list() == []

    RateLimiter.log_request(registered_user, "/_health?some=value")
    assert RateLimiter.list() == []
  end
end
