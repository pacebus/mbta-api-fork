defmodule ApiWeb.StatusControllerTest do
  use ApiWeb.ConnCase

  test "returns service metadata", %{conn: conn} do
    State.Feed.new_state(%Model.Feed{version: "TEST"})
    conn = get(conn, status_path(conn, :index))
    assert json = json_response(conn, 200)
    assert_attribute_key(json, "feed_version")
    assert_attribute_key(json, "alert")
    assert_attribute_key(json, "facility")
    assert_attribute_key(json, "prediction")
    assert_attribute_key(json, "route")
    assert_attribute_key(json, "schedule")
    assert_attribute_key(json, "service")
    assert_attribute_key(json, "shape")
    assert_attribute_key(json, "stop")
    assert_attribute_key(json, "trip")
    assert_attribute_key(json, "vehicle")
  end

  def assert_attribute_key(json, attribute_key) do
    assert get_in(json, ["data", "attributes", attribute_key])
  end
end
