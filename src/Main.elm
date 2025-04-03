module Main exposing (main)

import Autocomplete
import Browser
import Html exposing (..)
import Html.Attributes as Attributes
import Html.Events
import Time



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
                ( autocomplete, cmd ) =
                    Autocomplete.update GotAutocompleteMsg
                        autocompleteMsg
                        model.autocomplete
            in
            ( { model
                | autocomplete = autocomplete
              }
            , cmd
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    Html.div
        [ Attributes.class "text-neutral-950" ]
        [ Html.text "Hello, World!"
        , Autocomplete.view GotAutocompleteMsg model.autocomplete
        ]
