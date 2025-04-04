port module Main exposing (main)

import Api.Coordinates as Coordinates exposing (Coordinates)
import Api.Mapbox as Mapbox
import ApiData exposing (ApiData)
import Autocomplete
import Browser
import Html exposing (Html)
import Html.Attributes as Attributes
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
    }


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
    | GotAutocompleteMsg Autocomplete.Msg
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
                    , Cmd.none
                    )

                JsSentUserCurrentPosition result ->
                    ( Ok { okModel | userCurrentPosition = RemoteData.fromResult result }
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
                [ Html.div [ Attributes.class "grid grid-cols-1 gap-4 @min-xl:grid-cols-[auto_1fr]" ]
                    [ Html.div
                        [ Attributes.class "min-w-[clamp(18rem,_50cqi,_24rem)]" ]
                        [ Html.map GotAutocompleteMsg
                            (Autocomplete.view okModel.autocomplete)
                        , case ( ApiData.value okModel.selectedLocation, ApiData.isLoading okModel.selectedLocation ) of
                            ( ApiData.Empty, False ) ->
                                Html.text ""

                            ( ApiData.Empty, True ) ->
                                Html.div
                                    [ Attributes.class "text-gray-700" ]
                                    [ Html.text "Loading..." ]

                            ( ApiData.HttpError _, _ ) ->
                                Html.div
                                    [ Attributes.class "text-red-500" ]
                                    [ Html.text "Something went wrong!" ]

                            ( ApiData.Success feature, _ ) ->
                                Html.div
                                    [ Attributes.class "" ]
                                    [ Html.text ("Success: " ++ Mapbox.name feature) ]
                        ]
                    , Html.div [ Attributes.class "h-[50vh] min-h-[28rem]" ]
                        [ MapboxGl.view
                            { center =
                                ApiData.toMaybe okModel.selectedLocation
                                    |> Maybe.map Mapbox.coordinates
                                    |> Maybe.Extra.orElse (RemoteData.toMaybe okModel.userCurrentPosition)
                            }
                        ]
                    ]
                ]
