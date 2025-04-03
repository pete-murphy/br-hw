module Main exposing (main)

import Api.Mapbox exposing (Suggestion)
import Autocomplete
import Browser
import Html exposing (..)
import Html.Attributes as Attributes
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode



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

                        Just (Autocomplete.OutMsgUserSelectedSuggestion location) ->
                            ( Ok { okModel | autocomplete = autocomplete }
                            , Cmd.batch
                                [ Cmd.map GotAutocompleteMsg cmd
                                , getLocation location
                                ]
                            )


getLocation : Suggestion -> Cmd Msg
getLocation suggestion =
    -- Here you would implement the logic to get the location
    -- For example, you could use a Cmd to make an HTTP request
    -- to a geolocation API or similar.
    Cmd.none


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
                [ Html.text "Hello, World!"
                , Html.map GotAutocompleteMsg
                    (Autocomplete.view okModel.autocomplete)
                ]
