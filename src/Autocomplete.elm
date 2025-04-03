module Autocomplete exposing
    ( Model
    , Msg
    , init
    , view
    )

import Accessibility as Html exposing (Attribute, Html)
import Accessibility.Aria as Aria
import Accessibility.Live as Live
import Accessibility.Role as Role
import Debouncer exposing (Debouncer)
import Html.Attributes as Attributes


type alias Model =
    { expanded : Bool
    , debouncer : Debouncer (Maybe String)
    }


init : Model
init =
    { expanded = False
    , debouncer = Debouncer.init
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


type Msg
    = NoOp


view : (Msg -> msg) -> Model -> Html msg
view fromMsg model =
    let
        listboxId =
            "autocomplete-options"
    in
    Html.div
        [ Attributes.class "p-2 max-w-lg grid gap-2" ]
        [ Html.labelBefore [ Attributes.class "peer grid gap-2" ]
            (Html.span
                [ Attributes.class "uppercase font-semibold text-sm tracking-wide"
                ]
                [ Html.text "Find in-store" ]
            )
            (Html.inputText ""
                [ Aria.owns [ listboxId ]
                , Aria.autoCompleteList
                , Role.comboBox
                , Attributes.placeholder "Enter a location"
                , Attributes.autocomplete False
                , Attributes.attribute "autocapitalize" "none"
                , Attributes.class "border border-neutral-500 border-solid p-2 focus-visible:ring-2 outline-none focus-visible:ring-accent-600 placeholder:text-neutral-500"
                , Aria.expanded model.expanded
                ]
            )
        , Html.ul
            [ Role.listBox
            , Attributes.id listboxId
            , Attributes.class "opacity-0 h-0 transition-[height,_opacity] peer-[:not(:has(:placeholder-shown))]:h-[calc-size(auto,_size)] peer-[:not(:has(:placeholder-shown))]:opacity-100 overflow-clip transition-discrete border border-neutral-500 border-solid bg-white shadow-md"
            ]
            [ Html.li
                [ Role.option
                , Attributes.class "p-2"
                , Attributes.tabindex -1
                ]
                [ Html.text "France" ]
            ]
        , Html.div
            [ Attributes.class "sr-only"
            , Live.polite
            , Role.status
            ]
            []
        ]
