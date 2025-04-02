module Main exposing (main)

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
    {}


init : () -> ( Model, Cmd Msg )
init flags =
    ( {}
    , Cmd.none
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    Html.div
        [ Attributes.class "rounded-2xl bg-red-50" ]
        [ Html.text "Hello, World!" ]
