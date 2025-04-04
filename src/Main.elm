port module Main exposing (main)

import Api.Boobook as Boobook
import Api.Coordinates as Coordinates exposing (Coordinates)
import Api.Mapbox as Mapbox
import ApiData exposing (ApiData)
import Autocomplete
import Browser
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Parser.Util
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode
import MapboxGl
import Maybe.Extra
import RemoteData exposing (RemoteData)
import Result.Extra



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
    , mapboxSessionToken : String
    , selectedLocation : ApiData (Mapbox.Feature Mapbox.Retrieved)
    , userCurrentPosition : RemoteData String Coordinates
    , nearbyRetailersResponse : ApiData Boobook.Response
    , mapView : Maybe MapboxGl.MapView
    }


centeredCoordinates : OkModel -> Maybe Coordinates
centeredCoordinates okModel =
    ApiData.toMaybe okModel.selectedLocation
        |> Maybe.map Mapbox.coordinates
        |> Maybe.Extra.orElse (RemoteData.toMaybe okModel.userCurrentPosition)


type alias Flags =
    { mapboxAccessToken : String
    , mapboxSessionToken : String
    }


flagsDecoder : Decode.Decoder Flags
flagsDecoder =
    Decode.succeed Flags
        |> Pipeline.required "mapboxAccessToken" Decode.string
        |> Pipeline.required "mapboxSessionToken" Decode.string


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
                    let
                        ( autocomplete, cmd, outMsg ) =
                            Autocomplete.update { mapboxAccessToken = okModel.mapboxAccessToken, mapboxSessionToken = okModel.mapboxSessionToken }
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
                                    , mapboxSessionToken = okModel.mapboxSessionToken
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

                ApiRespondedWithNearbyRetailers coordinates result ->
                    -- if (Maybe.map .center okModel.mapView |> Maybe.Extra.orElse (centeredCoordinates okModel)) == Just coordinates then
                    ( Ok { okModel | nearbyRetailersResponse = ApiData.fromResult result }
                    , Cmd.none
                    )

                -- else
                --     ( Ok okModel
                --     , Cmd.none
                --     )
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
                                Decode.map Ok Coordinates.decoder

                            "CurrentPositionError" ->
                                Decode.map Err (Decode.field "error" Decode.string)

                            _ ->
                                Decode.fail "Unexpected type"
                    )
            )
            >> Result.Extra.unpack (\_ -> NoOp) JsSentUserCurrentPosition
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
            Html.main_ [ Attributes.class "grid @container text-gray-950" ]
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
                            }
                        ]
                    , Html.div [ Attributes.class "overflow-auto h-full max-h-[12rem] @min-xl:max-h-full @min-xl:[grid-row:2] @min-xl:[grid-column:1]" ]
                        (case ( ApiData.value okModel.nearbyRetailersResponse, ApiData.isLoading okModel.nearbyRetailersResponse ) of
                            ( ApiData.Empty, False ) ->
                                []

                            ( ApiData.Empty, True ) ->
                                [ Html.div
                                    [ Attributes.class "text-gray-700" ]
                                    [ Html.text "Loading nearby retailers..." ]
                                ]

                            ( ApiData.HttpError _, _ ) ->
                                [ Html.div
                                    [ Attributes.class "text-red-500" ]
                                    [ Html.text "Something went wrong!" ]
                                ]

                            ( ApiData.Success response, _ ) ->
                                [ if List.length response.problems == 0 then
                                    Html.text ""

                                  else
                                    Html.text (Debug.toString response.problems)
                                , case response.retailers of
                                    [] ->
                                        Html.text "No nearby retailers found."

                                    _ ->
                                        Html.ul [ Attributes.class "grid gap-1 py-1" ]
                                            (response.retailers
                                                |> List.map
                                                    (\retailer ->
                                                        Html.li
                                                            [ Attributes.class "py-1 px-6" ]
                                                            [ Html.h2 [ Attributes.class "" ]
                                                                [ Html.text retailer.name ]
                                                            , Html.address [ Attributes.class "text-sm not-italic font-light text-gray-700" ]
                                                                (Html.Parser.Util.toVirtualDom
                                                                    retailer.address
                                                                )
                                                            ]
                                                    )
                                            )
                                ]
                        )
                    ]

                -- , Html.div
                --     [ Attributes.class "font-mono text-sm text-gray-700 break-words pre"
                --     ]
                --     [ Html.text (Debug.toString okModel)
                --     ]
                ]
