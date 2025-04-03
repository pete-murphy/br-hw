module Autocomplete exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Accessibility as Html exposing (Attribute, Html)
import Accessibility.Aria as Aria
import Accessibility.Live as Live
import Accessibility.Role as Role
import Api.Mapbox.Suggestion as Suggestion exposing (Suggestion)
import Cmd.Extra
import Debouncer exposing (Debouncer)
import Html as Html_
import Html.Attributes as Attributes
import Html.Events as Events
import Html.Events.Extra
import Json.Decode as Decode
import RemoteData exposing (RemoteData(..), WebData)


type Focus
    = Input
    | Listbox { index : Int }
    | Elsewhere


incrementFocus : Int -> Focus -> Focus
incrementFocus optionsLength focus =
    case ( optionsLength == 0, focus ) of
        ( True, _ ) ->
            Input

        ( _, Input ) ->
            Listbox { index = 0 }

        ( _, Listbox { index } ) ->
            Listbox { index = Basics.min (optionsLength - 1) (index + 1) }

        ( _, Elsewhere ) ->
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


type Value
    = InputText String
    | SelectedSuggestion Suggestion



-- MODEL


type alias Model =
    { value : Value
    , searchResults : WebData (List Suggestion)
    , debouncer : Debouncer String
    , focus : Focus
    }


init : Model
init =
    { value = InputText ""
    , searchResults = NotAsked
    , debouncer = Debouncer.init
    , focus = Elsewhere
    }


filterOptions : String -> List Suggestion
filterOptions search =
    Suggestion.sampleSuggestions
        |> List.filter
            (\suggestion ->
                String.contains (String.toLower search) (String.toLower suggestion.name)
            )



-- UPDATE


type Msg
    = UserEnteredDebouncedSearch String
    | UserEnteredSearch String
    | GotDebouncerMsg Debouncer.Msg
    | UserFocused Focus
    | UserBlurred Focus
    | UserClicked Focus
    | UserPressedArrowUpKey
    | UserPressedArrowDownKey
    | AttemptBlur Focus
    | UserSelectedSuggestion Suggestion


type OutMsg
    = OutMsgUserSelectedSuggestion Suggestion


update : Msg -> Model -> ( Model, Cmd Msg, Maybe OutMsg )
update msg model =
    case msg of
        UserEnteredSearch search ->
            let
                ( debouncer, cmd ) =
                    Debouncer.call debouncerConfig search model.debouncer
            in
            ( { model
                | value = InputText search
                , debouncer = debouncer
              }
            , cmd
            , Nothing
            )

        UserEnteredDebouncedSearch search ->
            ( { model
                | searchResults =
                    case search of
                        "" ->
                            NotAsked

                        _ ->
                            Success (filterOptions search)
              }
            , Cmd.none
            , Nothing
            )

        GotDebouncerMsg debouncerMsg ->
            let
                ( debouncer, cmd ) =
                    Debouncer.update debouncerConfig debouncerMsg model.debouncer
            in
            ( { model | debouncer = debouncer }
            , cmd
            , Nothing
            )

        UserPressedArrowDownKey ->
            case model.searchResults of
                Success [] ->
                    ( model, Cmd.none, Nothing )

                Success filteredOptions ->
                    ( { model | focus = incrementFocus (List.length filteredOptions) model.focus }, Cmd.none, Nothing )

                _ ->
                    ( model, Cmd.none, Nothing )

        UserPressedArrowUpKey ->
            ( { model | focus = decrementFocus model.focus }, Cmd.none, Nothing )

        UserFocused focus ->
            ( { model | focus = focus }, Cmd.none, Nothing )

        UserBlurred focus ->
            ( model, Cmd.Extra.perform (AttemptBlur focus), Nothing )

        UserClicked focus ->
            ( { model | focus = focus }
            , Cmd.none
            , Nothing
            )

        UserSelectedSuggestion suggestion ->
            ( { model
                | value = SelectedSuggestion suggestion
                , focus = Input
              }
            , Cmd.none
            , Just (OutMsgUserSelectedSuggestion suggestion)
            )

        AttemptBlur focus ->
            -- We need to wait a tick to see if the focus has been set by some
            -- other message (like arrow key up/down)
            ( { model
                | focus =
                    if model.focus == focus then
                        Elsewhere

                    else
                        model.focus
              }
            , Cmd.none
            , Nothing
            )


debouncerConfig : Debouncer.Config String Msg
debouncerConfig =
    Debouncer.trailing
        { wait = 200
        , onReady = UserEnteredDebouncedSearch
        , onChange = GotDebouncerMsg
        }



-- VIEW


view : Model -> Html Msg
view model =
    let
        listboxId =
            "autocomplete-options"

        isExpanded =
            case ( model.searchResults, model.focus, model.value ) of
                ( NotAsked, _, _ ) ->
                    False

                ( _, Listbox _, _ ) ->
                    True

                ( _, Elsewhere, _ ) ->
                    False

                ( _, _, SelectedSuggestion _ ) ->
                    False

                ( _, _, _ ) ->
                    True
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
                [ Html.inputText
                    (case model.value of
                        InputText search ->
                            search

                        SelectedSuggestion suggestion ->
                            suggestion.name
                    )
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
                    , Attributes.class "grid border border-neutral-500 border-solid p-2 focus-visible:ring-2 outline-none focus-visible:ring-accent-600 placeholder:text-neutral-500"
                    ]
                ]
            )
        , Html.div
            [ Role.listBox
            , Attributes.id listboxId
            , Attributes.class "group opacity-0 h-0 transition-[height,_opacity]  overflow-clip transition-discrete border border-neutral-500 border-solid bg-white shadow-md"
            , Attributes.classList
                [ ( "h-[calc-size(auto,_size)] opacity-100", isExpanded ) ]
            ]
            [ case model.searchResults of
                Success [] ->
                    Html.div [ Attributes.class "p-2" ]
                        [ Html.text "No results found" ]

                Success results ->
                    Html.ul []
                        (results
                            |> List.indexedMap
                                (\i suggestion ->
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
                                                [ Attributes.class "outline-none w-full text-start p-2 focus:bg-neutral-700 focus:text-white active:bg-neutral-800 group-hover:not-hover:focus:bg-neutral-600 active:transition-colors hover:not-focus:bg-neutral-300"
                                                , Attributes.tabindex -1
                                                , Events.onBlur (UserBlurred (Listbox { index = i }))
                                                , Events.onFocus (UserFocused (Listbox { index = i }))
                                                , Events.onClick (UserSelectedSuggestion suggestion)
                                                , Html.Events.Extra.onKeyDown
                                                    [ ( "Enter", UserSelectedSuggestion suggestion )
                                                    , ( "Space", UserSelectedSuggestion suggestion )
                                                    ]
                                                ]
                                                [ Html.text suggestion.name ]
                                            ]
                                        ]
                                )
                        )

                Loading ->
                    Html.div [ Attributes.class "p-2" ]
                        [ Html.text "Loading..." ]

                NotAsked ->
                    Html.div [ Attributes.class "p-2 h-[1lh]" ]
                        [ Html.text "" ]

                Failure _ ->
                    Html.div [ Attributes.class "p-2" ]
                        [ Html.text "Something went wrong!" ]
            ]
        , Html.div
            [ Attributes.class "sr-only"
            , Live.polite
            , Role.status
            ]
            []
        ]


focusWithin :
    Bool
    -> List (Attribute Msg)
    -> List (Html Msg)
    -> Html Msg
focusWithin hasFocus attributes =
    Html_.node "focus-within"
        ([ Html.Events.Extra.onKeyDown
            [ ( "ArrowDown", UserPressedArrowDownKey )
            , ( "ArrowUp", UserPressedArrowUpKey )
            , ( "Escape", UserFocused Input )
            ]
         , Attributes.attribute "hasfocus"
            (if hasFocus then
                "true"

             else
                ""
            )
         , Events.custom "remove"
            (Decode.succeed
                { message = UserFocused Input
                , stopPropagation = False
                , preventDefault = False
                }
            )
         ]
            ++ attributes
        )
