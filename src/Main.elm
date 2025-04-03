module Main exposing (main)

import Api.Mapbox as Mapbox
import Autocomplete
import Browser
import Html exposing (..)
import Html.Attributes as Attributes
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode
import RemoteData exposing (WebData)



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
    , selectedLocation : WebData (Mapbox.Feature Mapbox.Retrieved)
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
                , selectedLocation = RemoteData.NotAsked
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
                                    , selectedLocation = RemoteData.Loading
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
                    ( Ok { okModel | selectedLocation = RemoteData.fromResult result }
                    , Cmd.none
                    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    case model of
        Err err ->
            Html.div
                [ Attributes.class "text-red-500" ]
                [ Html.text ("Error: " ++ Decode.errorToString err) ]

        Ok okModel ->
            Html.div
                [ Attributes.class "text-neutral-950" ]
                [ Html.map GotAutocompleteMsg
                    (Autocomplete.view okModel.autocomplete)
                , Html.div []
                    [ Html.text (Debug.toString okModel.selectedLocation)
                    ]
                ]
