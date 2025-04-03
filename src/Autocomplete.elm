module Autocomplete exposing
    ( Model
    , Msg
    , init
    , update
    , view
    )

import Accessibility as Html exposing (Attribute, Html)
import Accessibility.Aria as Aria
import Accessibility.Live as Live
import Accessibility.Role as Role
import Cmd.Extra
import Debouncer exposing (Debouncer)
import Html as Html_
import Html.Attributes as Attributes
import Html.Events as Events
import Html.Events.Extra
import Json.Decode as Decode
import Json.Encode
import RemoteData exposing (RemoteData(..), WebData)


type alias Location =
    { name : String

    -- , address : String
    -- , latitude : Float
    -- , longitude : Float
    , id : String
    }


type Focus
    = Input
    | Listbox { index : Int }
    | Elsewhere


incrementFocus : Int -> Focus -> Focus
incrementFocus optionsLength focus =
    case focus of
        Input ->
            Listbox { index = 0 }

        Listbox { index } ->
            Listbox { index = Basics.min (optionsLength - 1) (index + 1) }

        Elsewhere ->
            Input


decrementFocus : Focus -> Focus
decrementFocus focus =
    case focus of
        Input ->
            Input

        Listbox { index } ->
            if index == 0 then
                Input

            else
                Listbox { index = index - 1 }

        Elsewhere ->
            Input


listboxHasFocus : Focus -> Bool
listboxHasFocus focus =
    case focus of
        Input ->
            False

        Listbox _ ->
            True

        Elsewhere ->
            False



-- MODEL


type alias Model =
    { searchInput : String
    , searchResults : WebData (List Location)
    , debouncer : Debouncer String
    , focus : Focus
    , selectedLocation : Maybe Location

    -- , inputHasFocus : Bool
    -- , listboxHasFocus : Bool
    }


init : Model
init =
    { searchInput = ""
    , searchResults = NotAsked
    , debouncer = Debouncer.init
    , focus = Elsewhere
    , selectedLocation = Nothing
    }


options =
    [ { name = "France", id = "1" }
    , { name = "Germany", id = "2" }
    , { name = "Italy", id = "3" }
    , { name = "Spain", id = "4" }
    , { name = "United Kingdom", id = "5" }
    , { name = "United States", id = "6" }
    ]



-- UPDATE


type Msg
    = UserEnteredDebouncedSearch String
    | UserEnteredSearch String
    | GotDebouncerMsg Debouncer.Msg
    | UserFocused Focus
    | UserBlurred Focus
    | UserClicked Focus
    | UserPressedUpKey
    | UserPressedDownKey
    | AttemptBlur Focus
    | UserSelected Location
      -- | AttemptBlurListbox
    | NoOp


update : (Msg -> msg) -> Msg -> Model -> ( Model, Cmd msg )
update fromMsg msg model =
    update_ msg model
        |> Tuple.mapSecond (Cmd.map fromMsg)


update_ : Msg -> Model -> ( Model, Cmd Msg )
update_ msg model =
    case msg of
        NoOp ->
            let
                _ =
                    Debug.log "NoOp" ()
            in
            ( model, Cmd.none )

        UserEnteredSearch search ->
            let
                ( debouncer, cmd ) =
                    Debouncer.call debouncerConfig search model.debouncer
            in
            ( { model
                | searchInput = search
                , debouncer = debouncer
              }
            , cmd
            )

        UserEnteredDebouncedSearch search ->
            ( model, Cmd.none )

        GotDebouncerMsg debouncerMsg ->
            let
                ( debouncer, cmd ) =
                    Debouncer.update debouncerConfig debouncerMsg model.debouncer
            in
            ( { model | debouncer = debouncer }
            , cmd
            )

        UserPressedDownKey ->
            ( { model | focus = incrementFocus (List.length options) model.focus }, Cmd.none )

        UserPressedUpKey ->
            ( { model | focus = decrementFocus model.focus }, Cmd.none )

        UserFocused focus ->
            ( { model | focus = focus }, Cmd.none )

        UserBlurred focus ->
            ( model, Cmd.Extra.perform (AttemptBlur focus) )

        UserClicked focus ->
            ( { model | focus = focus }
            , Cmd.none
            )

        UserSelected location ->
            ( { model
                | searchInput = ""
                , focus = Input
                , searchResults =
                    RemoteData.Loading
                , selectedLocation = Just location
              }
            , Cmd.none
            )

        AttemptBlur focus ->
            ( { model
                | focus =
                    if model.focus == focus then
                        Elsewhere

                    else
                        model.focus
              }
            , Cmd.none
            )



-- AttemptBlurListbox ->
--     ( { model
--         | focus =
--             if listboxHasFocus model.focus then
--                 Elsewhere
--             else
--                 model.focus
--       }
--     , Cmd.none
--     )


debouncerConfig : Debouncer.Config String Msg
debouncerConfig =
    Debouncer.trailing
        { wait = 200
        , onReady = UserEnteredDebouncedSearch
        , onChange = GotDebouncerMsg
        }



-- VIEW


view : (Msg -> msg) -> Model -> Html msg
view fromMsg model =
    view_ model
        |> Html.map fromMsg


view_ : Model -> Html Msg
view_ model =
    let
        listboxId =
            "autocomplete-options"

        isExpanded =
            model.searchInput
                /= ""
                || listboxHasFocus model.focus
    in
    Html.div
        [ Attributes.class "p-2 max-w-lg grid gap-2"
        ]
        [ Html.labelBefore [ Attributes.class "peer grid gap-2" ]
            (Html.span
                [ Attributes.class "uppercase font-semibold text-sm tracking-wide"
                ]
                [ Html.text "Find in-store" ]
            )
            (focusWithin (model.focus == Input)
                [ Attributes.class "grid"
                ]
                [ Html.inputText model.searchInput
                    [ Aria.owns [ listboxId ]
                    , Aria.autoCompleteList
                    , Role.comboBox
                    , Attributes.placeholder "Enter a location"
                    , Attributes.autocomplete False
                    , Attributes.attribute "autocapitalize" "none"
                    , Aria.expanded isExpanded
                    , Events.onInput UserEnteredSearch
                    , Events.onFocus (UserFocused Input)
                    , Events.onBlur (UserBlurred Input)
                    , Attributes.class "grid border border-neutral-500 border-solid p-2 has-focus-visible:ring-2 outline-none has-focus-visible:ring-accent-600 placeholder:text-neutral-500"
                    ]
                ]
            )
        , Html.ul
            [ Role.listBox
            , Attributes.id listboxId
            , Attributes.class "opacity-0 h-0 transition-[height,_opacity]  overflow-clip transition-discrete border border-neutral-500 border-solid bg-white shadow-md"
            , Attributes.classList
                [ ( "h-[calc-size(auto,_size)] opacity-100", isExpanded ) ]
            ]
            (options
                |> List.indexedMap
                    (\i location ->
                        let
                            hasFocus =
                                model.focus == Listbox { index = i }
                        in
                        Html.li
                            [ Attributes.attribute "aria-selected"
                                (if hasFocus then
                                    "true"

                                 else
                                    "false"
                                )
                            ]
                            [ focusWithin hasFocus
                                []
                                [ Html.button
                                    [ Attributes.class "w-full text-start p-2 focus:bg-accent-600 focus:text-white active:bg-accent-900 active:transition-colors  hover:bg-accent-600 hover:text-white outline-none"
                                    , Attributes.tabindex -1
                                    , Events.onBlur (UserBlurred (Listbox { index = i }))
                                    , Events.onFocus (UserFocused (Listbox { index = i }))
                                    , Events.onClick (UserSelected location)
                                    , Html.Events.Extra.onKeyDown
                                        [ ( "Enter", UserSelected location )
                                        , ( "Space", UserSelected location )
                                        ]

                                    -- , Events.onClick (UserClicked (Listbox { index = i }))
                                    ]
                                    [ Html.text location.name ]
                                ]
                            ]
                    )
            )
        , Html.div
            [ Attributes.class "sr-only"
            , Live.polite
            , Role.status
            ]
            []
        , Html.div []
            [ Html.text (Debug.toString model) ]
        ]


focusWithin :
    Bool
    -> List (Attribute Msg)
    -> List (Html Msg)
    -> Html Msg
focusWithin hasFocus attributes =
    Html_.node "focus-within"
        ([ Html.Events.Extra.onKeyDown
            [ ( "ArrowDown", UserPressedDownKey )
            , ( "ArrowUp", UserPressedUpKey )
            ]
         , Attributes.attribute "hasfocus"
            (if hasFocus then
                "true"

             else
                ""
            )
         , Events.custom "remove"
            (Decode.succeed
                { message = NoOp
                , stopPropagation = False
                , preventDefault = False
                }
            )
         ]
            ++ attributes
        )
