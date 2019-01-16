defmodule ApiWeb.FacilityController do
  use ApiWeb.Web, :api_controller
  alias State.Facility

  @filters ~w(stop type)s
  @pagination_opts [:offset, :limit, :order_by]

  def state_module, do: State.Facility

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List Escalators and Elevators

    #{swagger_path_description("/data")}
    """)

    common_index_parameters(__MODULE__)
    include_parameters(~w(stop))
    filter_param(:id, name: :stop)

    parameter(
      "filter[type]",
      :query,
      :string,
      "Filter by multiple types.  Multiple types **MUST** be a comma-separated (U+002C COMMA, \",\") list."
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Facilities))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(_conn, params) do
    params
    |> Params.filter_params(@filters)
    |> format_filters()
    |> Facility.filter_by()
    |> State.all(Params.filter_opts(params, @pagination_opts))
  end

  defp format_filters(filters) do
    filters
    |> Enum.flat_map(&do_format_filter/1)
    |> Enum.into(%{})
  end

  defp do_format_filter({"stop", stop_string}) do
    case Params.split_on_comma(stop_string) do
      [] ->
        []

      stop_ids ->
        %{stops: stop_ids}
    end
  end

  defp do_format_filter({"type", type_string}) do
    case Params.split_on_comma(type_string) do
      [] ->
        []

      types ->
        %{types: types}
    end
  end

  defp do_format_filter(_), do: []

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Specific Escalator or Elevator

    #{swagger_path_description("/data/{index}")}
    """)

    include_parameters(~w(stops))
    parameter(:id, :path, :string, "Unique identifier for facility")

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Facility))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => id}) do
    Facility.by_id(id)
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      FacilityProperty:
        swagger_schema do
          description("Name/value pair for additional facility information")
          example(%{name: "address", value: "197 Ivory St, Braintree, MA 02184"})

          properties do
            name(
              :string,
              "The name of the property",
              example: "address"
            )

            value(
              [:string, :integer],
              "The value of the property",
              example: "197 Ivory St, Braintree, MA 02184"
            )
          end
        end,
      FacilityResource:
        resource do
          description(swagger_path_description("*"))

          attributes do
            type(
              :string,
              "The type of the facility.",
              enum:
                ~w(BIKE_STORAGE ELECTRIC_CAR_CHARGERS ELEVATOR ESCALATOR PARKING_AREA PICK_DROP PORTABLE_BOARDING_LIFT TTY_PHONE ELEVATED_SUBPLATFORM),
              example: "ELEVATOR"
            )

            name(
              :string,
              "Name of the facility",
              example: "SHAWMUT - Ashmont Bound Platform to Lobby"
            )

            latitude(
              :number,
              """
              Latitude of the facility.  Degrees North, in the \
              [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS.C2.A084) \
              coordinate system. See \
              [GTFS `facilities.txt` `facility_lat`]
              """,
              example: -71.194994
            )

            longitude(
              :number,
              """
              Longitude of the facility. Degrees East, in the \
              [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#Longitudes_on_WGS.C2.A084) coordinate \
              system. See
              [GTFS `facilities.txt` `facility_lon`]
              """,
              example: 42.316115
            )

            properties(
              %Schema{
                type: :array,
                items: Schema.ref(:FacilityProperty)
              },
              "A list of name/value pairs that apply to the facility. See [MBTA's facility documentation](https://www.mbta.com/developers/gtfs/f#facilities_properties_definitions) for more information on the possible names and values."
            )
          end

          relationship(:stop)
        end,
      Facility: single(:FacilityResource),
      Facilities: page(:FacilityResource)
    }
  end

  defp swagger_path_description(parent_pointer) do
    """
    A facility at a station stop (`#{parent_pointer}/relationships/stop`) that connects one part of the station to
    another.

    An [MBTA extension](https://groups.google.com/forum/#!topic/gtfs-changes/EzC5m9k45pA).  This spec is not yet \
    finalized.

    ## Accessibility

    Riders with limited mobility can search any facility, either `ELEVATOR` or `ESCALATOR`, while riders that need \
    wheelchair access can search for `ELEVATOR` only.

    The lack of an `ELEVATOR` MAY NOT make a stop wheelchair inaccessible.  Riders should check `/stops/{id}` \
    `/data/attributes/wheelchair_boarding` is `1` to guarantee a path is available from the station entrance to the \
    stop or `0` if it MAY be accessible.  Completely avoid `2` as that is guaranteed to be INACCESSIBLE.
    """
  end
end
