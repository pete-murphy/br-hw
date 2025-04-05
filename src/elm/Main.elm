port module Main exposing (main)

import Accessibility.Live as Live
import Accessibility.Role as Role
import Api.Boobook as Boobook
import Api.Coordinates as Coordinates exposing (Coordinates)
import Api.Mapbox as Mapbox
import ApiData exposing (ApiData)
import Autocomplete
import Browser
import Html exposing (Attribute, Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Html.Parser.Util
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode
import MapboxGl
import Maybe.Extra
import RemoteData exposing (RemoteData)
import Result.Extra
import Svg
import Svg.Attributes



-- MAIN


main : Program Json.Encode.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Model =
    Result Decode.Error OkModel


type alias OkModel =
    { autocomplete : Autocomplete.Model
    , mapboxAccessToken : String
    , mapboxSessionToken : Maybe String
    , selectedLocation : ApiData (Mapbox.Feature Mapbox.Retrieved)
    , userCurrentPosition : RemoteData String Coordinates
    , nearbyRetailersResponse : ApiData Boobook.Response
    , highlightedRetailerId : Maybe String
    , mapView : Maybe MapboxGl.MapView
    }


centeredCoordinates : OkModel -> Maybe Coordinates
centeredCoordinates okModel =
    ApiData.toMaybe okModel.selectedLocation
        |> Maybe.map Mapbox.coordinates
        |> Maybe.Extra.orElse (RemoteData.toMaybe okModel.userCurrentPosition)


type alias Flags =
    { mapboxAccessToken : String
    , mapboxSessionToken : Maybe String
    }


flagsDecoder : Decode.Decoder Flags
flagsDecoder =
    Decode.succeed Flags
        |> Pipeline.required "mapboxAccessToken" Decode.string
        |> Pipeline.optional "mapboxSessionToken" (Decode.nullable Decode.string) Nothing


init : Json.Encode.Value -> ( Model, Cmd Msg )
init flags =
    case Decode.decodeValue flagsDecoder flags of
        Ok okFlags ->
            ( Ok
                { autocomplete = Autocomplete.init
                , mapboxAccessToken = okFlags.mapboxAccessToken
                , mapboxSessionToken = okFlags.mapboxSessionToken
                , selectedLocation = ApiData.notAsked
                , userCurrentPosition = RemoteData.NotAsked
                , nearbyRetailersResponse = ApiData.notAsked
                , highlightedRetailerId = Nothing
                , mapView = Nothing
                }
            , Cmd.none
            )

        Err err ->
            ( Err err
            , Cmd.none
            )



-- UPDATE


type Msg
    = NoOp
    | ApiRespondedWithRetrievedFeature (Result Http.Error (Mapbox.Feature Mapbox.Retrieved))
    | ApiRespondedWithNearbyRetailers Coordinates (Result Http.Error Boobook.Response)
    | GotAutocompleteMsg Autocomplete.Msg
    | UserMovedMap MapboxGl.MapView
    | JsSentUserCurrentPosition (Result String Coordinates)
    | JsSentMapboxSessionToken String
    | UserMouseEnteredMarker String
    | UserMouseLeftMarker


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        Err _ ->
            ( model, Cmd.none )

        Ok okModel ->
            case msg of
                NoOp ->
                    ( Ok okModel, Cmd.none )

                GotAutocompleteMsg autocompleteMsg ->
                    case okModel.mapboxSessionToken of
                        Nothing ->
                            ( Ok okModel
                            , Cmd.none
                            )

                        Just mapboxSessionToken ->
                            let
                                ( autocomplete, cmd, outMsg ) =
                                    Autocomplete.update { mapboxAccessToken = okModel.mapboxAccessToken, mapboxSessionToken = mapboxSessionToken }
                                        autocompleteMsg
                                        okModel.autocomplete
                            in
                            case outMsg of
                                Nothing ->
                                    ( Ok { okModel | autocomplete = autocomplete }
                                    , Cmd.map GotAutocompleteMsg cmd
                                    )

                                Just (Autocomplete.OutMsgUserSelectedSuggestion suggestion) ->
                                    ( Ok
                                        { okModel
                                            | autocomplete = autocomplete
                                            , selectedLocation = ApiData.toLoading okModel.selectedLocation
                                        }
                                    , Cmd.batch
                                        [ Cmd.map GotAutocompleteMsg cmd
                                        , Mapbox.retrieveSuggestion
                                            { mapboxAccessToken = okModel.mapboxAccessToken
                                            , mapboxSessionToken = mapboxSessionToken
                                            , mapboxId = Mapbox.mapboxId suggestion
                                            }
                                            ApiRespondedWithRetrievedFeature
                                        ]
                                    )

                ApiRespondedWithRetrievedFeature result ->
                    ( Ok { okModel | selectedLocation = ApiData.fromResult result }
                    , case Result.toMaybe result of
                        Just feature ->
                            let
                                coordinates =
                                    Mapbox.coordinates feature
                            in
                            Boobook.getNearby
                                { latitude = coordinates.latitude
                                , longitude = coordinates.longitude
                                , radiusInMeters =
                                    case Maybe.map .bounds okModel.mapView of
                                        Just ( southwest, northeast ) ->
                                            Basics.floor
                                                (Coordinates.distanceInKm southwest northeast
                                                    * 1000
                                                    / 2
                                                )

                                        Nothing ->
                                            1000
                                }
                                (ApiRespondedWithNearbyRetailers coordinates)

                        Nothing ->
                            Cmd.none
                    )

                ApiRespondedWithNearbyRetailers _ result ->
                    ( Ok { okModel | nearbyRetailersResponse = ApiData.fromResult result }
                    , Cmd.none
                    )

                JsSentUserCurrentPosition result ->
                    ( Ok { okModel | userCurrentPosition = RemoteData.fromResult result }
                    , case Result.toMaybe result of
                        Just coordinates ->
                            Boobook.getNearby
                                { latitude = coordinates.latitude
                                , longitude = coordinates.longitude
                                , radiusInMeters =
                                    case Maybe.map .bounds okModel.mapView of
                                        Just ( southwest, northeast ) ->
                                            Basics.floor
                                                (Coordinates.distanceInKm southwest northeast
                                                    * 1000
                                                    / 2
                                                )

                                        Nothing ->
                                            1000
                                }
                                (ApiRespondedWithNearbyRetailers coordinates)

                        Nothing ->
                            Cmd.none
                    )

                JsSentMapboxSessionToken mapboxSessionToken ->
                    ( Ok { okModel | mapboxSessionToken = Just mapboxSessionToken }
                    , Cmd.none
                    )

                UserMovedMap mapView ->
                    ( Ok { okModel | mapView = Just mapView }
                    , let
                        ( southwest, northeast ) =
                            mapView.bounds
                      in
                      Boobook.getNearby
                        { latitude = mapView.center.latitude
                        , longitude = mapView.center.longitude
                        , radiusInMeters =
                            Basics.floor
                                (Coordinates.distanceInKm southwest northeast
                                    * 1000
                                    / 2
                                )
                        }
                        (ApiRespondedWithNearbyRetailers southwest)
                    )

                UserMouseEnteredMarker id ->
                    ( Ok { okModel | highlightedRetailerId = Just id }
                    , Cmd.none
                    )

                UserMouseLeftMarker ->
                    ( Ok { okModel | highlightedRetailerId = Nothing }
                    , Cmd.none
                    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    fromJs
        (Decode.decodeValue
            (Decode.field "type" Decode.string
                |> Decode.andThen
                    (\str ->
                        case str of
                            "CurrentPositionSuccess" ->
                                Decode.map (JsSentUserCurrentPosition << Ok) Coordinates.decoder

                            "CurrentPositionError" ->
                                Decode.map (JsSentUserCurrentPosition << Err) (Decode.field "error" Decode.string)

                            "MapboxSessionToken" ->
                                Decode.map JsSentMapboxSessionToken (Decode.field "mapboxSessionToken" Decode.string)

                            _ ->
                                Decode.succeed NoOp
                    )
            )
            >> Result.Extra.unwrap NoOp identity
        )


port fromJs : (Json.Encode.Value -> msg) -> Sub msg



-- VIEW


view : Model -> Html Msg
view model =
    case model of
        Err err ->
            Html.div
                [ Attributes.class "text-red-500" ]
                [ Html.text ("Error: " ++ Decode.errorToString err) ]

        Ok okModel ->
            let
                retailersInView =
                    case ( ApiData.toMaybe okModel.nearbyRetailersResponse, okModel.mapView ) of
                        ( Just response, Just { bounds } ) ->
                            response.retailers
                                |> List.filter
                                    (\retailer ->
                                        let
                                            ( southwest, northeast ) =
                                                bounds
                                        in
                                        Coordinates.isInBounds
                                            { latitude = retailer.latitude
                                            , longitude = retailer.longitude
                                            }
                                            { southwest = southwest, northeast = northeast }
                                    )

                        _ ->
                            []
            in
            Html.main_ [ Attributes.class "grid @container text-grey-600" ]
                [ Html.div [ Attributes.class "grid grid-cols-1 grid-flow-row @min-xl:grid-cols-[clamp(18rem,_50cqi,_24rem)_1fr] @min-xl:grid-rows-[auto_1fr] @min-xl:h-[50vh] min-h-[28rem]" ]
                    [ Html.div [ Attributes.class "@min-xl:[grid-row:1] @min-xl:[grid-column:1]" ]
                        [ Html.div [ Attributes.class "" ]
                            [ Html.map GotAutocompleteMsg
                                (Autocomplete.view okModel.autocomplete)
                            ]
                        ]
                    , Html.div [ Attributes.class "@min-xl:[grid-column:2] @min-xl:[grid-row:1/span_2] h-[50vh] min-h-[28rem]" ]
                        [ MapboxGl.view
                            { center = centeredCoordinates okModel
                            , onMove = UserMovedMap
                            , markers =
                                retailersInView
                                    |> List.map
                                        (\retailer ->
                                            { id = retailer.id
                                            , latitude = retailer.latitude
                                            , longitude = retailer.longitude
                                            }
                                        )
                            , highlightedMarker = okModel.highlightedRetailerId
                            , onMarkerMouseEnter = UserMouseEnteredMarker
                            , onMarkerMouseLeave = \_ -> UserMouseLeftMarker
                            , accessToken = okModel.mapboxAccessToken
                            }
                        ]
                    , Html.div [ Attributes.class "overflow-auto h-full max-h-[12rem] @min-xl:max-h-full @min-xl:[grid-row:2] @min-xl:[grid-column:1]" ]
                        (case ( ApiData.value okModel.nearbyRetailersResponse, ApiData.isLoading okModel.nearbyRetailersResponse ) of
                            ( ApiData.Empty, False ) ->
                                []

                            ( ApiData.Empty, True ) ->
                                [ Html.div
                                    [ Attributes.class "py-2 px-6 text-gray-700" ]
                                    [ Html.text "Loading nearby retailers..." ]
                                ]

                            ( ApiData.HttpError _, _ ) ->
                                [ Html.div
                                    [ Attributes.class "py-2 px-6 text-red-500" ]
                                    [ Html.text "Something went wrong!" ]
                                ]

                            ( ApiData.Success response, isLoading ) ->
                                [ if List.length response.problems == 0 then
                                    Html.text ""

                                  else
                                    Html.ul
                                        [ Attributes.class "py-2 px-6 text-red-500" ]
                                        (response.problems
                                            |> List.map
                                                (\problem ->
                                                    Html.li
                                                        [ Attributes.class "" ]
                                                        [ Html.div [] [ Html.text problem.title ]
                                                        , Html.div [] [ Html.text problem.detail ]
                                                        ]
                                                )
                                        )
                                , Html.div
                                    [ Attributes.class "sr-only"
                                    , Live.polite
                                    , Role.status
                                    ]
                                    [ case response.retailers of
                                        [] ->
                                            if isLoading then
                                                Html.text "Loading nearby retailers..."

                                            else
                                                Html.text "No nearby retailers found."

                                        _ ->
                                            Html.text
                                                (String.fromInt (List.length response.retailers)
                                                    ++ " nearby retailers found."
                                                )
                                    ]
                                , case retailersInView of
                                    [] ->
                                        if isLoading then
                                            Html.div
                                                [ Attributes.class "py-2 px-6 text-gray-700" ]
                                                [ Html.text "Loading nearby retailers..." ]

                                        else
                                            Html.div
                                                [ Attributes.class "py-2 px-6 text-gray-700" ]
                                                [ Html.text "No nearby retailers found." ]

                                    _ ->
                                        Html.ul [ Attributes.class "grid gap-1 py-1 scroll-m-1" ]
                                            (retailersInView
                                                |> List.map
                                                    (\retailer ->
                                                        let
                                                            isHighlighted =
                                                                Just retailer.id == okModel.highlightedRetailerId
                                                        in
                                                        Html.li
                                                            [ Attributes.class "py-1 px-6"
                                                            , Events.onMouseEnter (UserMouseEnteredMarker retailer.id)
                                                            , Events.onMouseLeave UserMouseLeftMarker
                                                            ]
                                                            [ scrollIntoView isHighlighted
                                                                (Html.div [ Attributes.class "grid gap-2 grid-cols-[auto_1fr_auto]" ]
                                                                    [ Html.div [ Attributes.class "" ]
                                                                        [ Svg.svg
                                                                            [ Svg.Attributes.viewBox "0 0 24 24"
                                                                            , Svg.Attributes.fill "currentColor"
                                                                            , Svg.Attributes.class "transition size-6"
                                                                            , if isHighlighted then
                                                                                Svg.Attributes.class "text-accent-dark"

                                                                              else if Maybe.Extra.isJust okModel.highlightedRetailerId then
                                                                                Svg.Attributes.class "opacity-25"

                                                                              else
                                                                                Svg.Attributes.class ""
                                                                            ]
                                                                            [ Svg.path
                                                                                [ Svg.Attributes.fillRule "evenodd"
                                                                                , Svg.Attributes.d "m11.54 22.351.07.04.028.016a.76.76 0 0 0 .723 0l.028-.015.071-.041a16.975 16.975 0 0 0 1.144-.742 19.58 19.58 0 0 0 2.683-2.282c1.944-1.99 3.963-4.98 3.963-8.827a8.25 8.25 0 0 0-16.5 0c0 3.846 2.02 6.837 3.963 8.827a19.58 19.58 0 0 0 2.682 2.282 16.975 16.975 0 0 0 1.145.742ZM12 13.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"
                                                                                , Svg.Attributes.clipRule "evenodd"
                                                                                ]
                                                                                []
                                                                            ]
                                                                        ]
                                                                    , Html.div [ Attributes.class "grid gap-0.5" ]
                                                                        [ Html.h2 [ Attributes.class "" ]
                                                                            [ Html.text retailer.name ]
                                                                        , Html.address [ Attributes.class "text-sm not-italic font-light text-gray-700" ]
                                                                            (Html.Parser.Util.toVirtualDom
                                                                                retailer.address
                                                                            )
                                                                        ]
                                                                    , Html.div [ Attributes.class "text-sm font-light text-gray-700" ]
                                                                        [ distanceFormatter { distanceInKms = retailer.distanceInKms }
                                                                            []
                                                                        ]
                                                                    ]
                                                                )
                                                            ]
                                                    )
                                            )
                                ]
                        )
                    ]
                ]


distanceFormatter :
    { distanceInKms : Float }
    -> List (Attribute msg)
    -> Html msg
distanceFormatter { distanceInKms } attrs =
    Html.node "distance-formatter"
        (Attributes.attribute "distance" (String.fromFloat distanceInKms)
            :: attrs
        )
        []


scrollIntoView : Bool -> Html msg -> Html msg
scrollIntoView scroll children =
    Html.node "scroll-into-view"
        [ Attributes.attribute "scroll"
            (if scroll then
                "true"

             else
                "false"
            )
        ]
        [ children ]
