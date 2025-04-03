module Main exposing (main)

import Api.Mapbox.Suggestion exposing (Suggestion)
import Autocomplete
import Browser
import Html exposing (..)
import Html.Attributes as Attributes



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Model =
    { autocomplete : Autocomplete.Model
    }


init : () -> ( Model, Cmd Msg )
init flags =
    ( { autocomplete = Autocomplete.init
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = NoOp
    | GotAutocompleteMsg Autocomplete.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotAutocompleteMsg autocompleteMsg ->
            let
                ( autocomplete, cmd, outMsg ) =
                    Autocomplete.update
                        autocompleteMsg
                        model.autocomplete
            in
            case outMsg of
                Nothing ->
                    ( { model | autocomplete = autocomplete }
                    , Cmd.map GotAutocompleteMsg cmd
                    )

                Just (Autocomplete.OutMsgUserSelectedSuggestion location) ->
                    ( { model | autocomplete = autocomplete }
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
    Html.div
        [ Attributes.class "text-neutral-950" ]
        [ Html.text "Hello, World!"
        , Html.map GotAutocompleteMsg
            (Autocomplete.view model.autocomplete)
        ]
