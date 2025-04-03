module Autocomplete exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Accessibility exposing (Attribute, Html)
import Accessibility.Aria as Aria
import Accessibility.Live as Live
import Accessibility.Role as Role
import Api.Mapbox as Mapbox
import Cmd.Extra
import Debouncer exposing (Debouncer)
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Html.Events.Extra
import Http
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
    | SelectedSuggestion (Mapbox.Feature Mapbox.Suggestion)


type CursorAction
    = MoveLeft
    | MoveRight



-- MODEL


type alias Model =
    { value : Value
    , searchResults : WebData (List (Mapbox.Feature Mapbox.Suggestion))
    , pendingRequestId : Maybe String
    , debouncer : Debouncer String
    , focus : Focus
    , cursorAction : Maybe CursorAction
    }


init : Model
init =
    { value = InputText ""
    , searchResults = NotAsked
    , pendingRequestId = Nothing
    , debouncer = Debouncer.init
    , focus = Elsewhere
    , cursorAction = Nothing
    }



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
    | UserPressedArrowLeftKey
    | UserPressedArrowRightKey
    | UserSelectedSuggestion (Mapbox.Feature Mapbox.Suggestion)
    | UserClearedInput
    | UserPressedPrintableCharacterKey Char
    | ApiRespondedWithSuggestions String (Result Http.Error (List (Mapbox.Feature Mapbox.Suggestion)))
      -- Imperative
    | ResetCursorAction
    | AttemptBlur Focus
    | NoOp


type OutMsg
    = OutMsgUserSelectedSuggestion (Mapbox.Feature Mapbox.Suggestion)


update :
    { mapboxAccessToken : String
    , mapboxSessionToken : String
    }
    -> Msg
    -> Model
    -> ( Model, Cmd Msg, Maybe OutMsg )
update params msg model =
    let
        cancelPendingSearch =
            case model.pendingRequestId of
                Nothing ->
                    Cmd.none

                Just id ->
                    Http.cancel id
    in
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
                            Loading
                , pendingRequestId =
                    case search of
                        "" ->
                            Nothing

                        _ ->
                            Just search
              }
            , if search == "" then
                cancelPendingSearch

              else
                Mapbox.getSuggestions
                    { mapboxAccessToken = params.mapboxAccessToken
                    , mapboxSessionToken = params.mapboxSessionToken
                    , query = search
                    }
                    (ApiRespondedWithSuggestions search)
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

        UserPressedArrowLeftKey ->
            ( { model | focus = Input, cursorAction = Just MoveLeft }, Cmd.none, Nothing )

        UserPressedArrowRightKey ->
            ( { model | focus = Input, cursorAction = Just MoveRight }, Cmd.none, Nothing )

        ResetCursorAction ->
            ( { model | cursorAction = Nothing }, Cmd.none, Nothing )

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

        UserPressedPrintableCharacterKey _ ->
            ( { model | focus = Input }
            , Cmd.none
            , Nothing
            )

        ApiRespondedWithSuggestions searchTerm result ->
            ( if model.pendingRequestId == Just searchTerm then
                { model | searchResults = RemoteData.fromResult result }

              else
                model
            , Cmd.none
            , Nothing
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

        UserClearedInput ->
            ( { model
                | value = InputText ""
                , searchResults = NotAsked
                , pendingRequestId = Nothing
                , focus = Input
              }
            , cancelPendingSearch
            , Nothing
            )

        NoOp ->
            ( model, Cmd.none, Nothing )


debouncerConfig : Debouncer.Config String Msg
debouncerConfig =
    Debouncer.trailing
        { wait = 500
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
        [ Attributes.class "grid gap-2 p-2 w-xs"
        ]
        [ Accessibility.labelBefore [ Attributes.class "grid gap-2 peer" ]
            (Html.span
                [ Attributes.class "text-sm font-semibold tracking-wide uppercase"
                ]
                [ Html.text "Find in-store" ]
            )
            (inputFocusManager
                { hasFocus = model.focus == Input
                , cursorAction = model.cursorAction
                }
                [ Attributes.class "grid"
                , Html.Events.Extra.onKeyDown
                    (\key ->
                        case key of
                            Just "ArrowDown" ->
                                UserPressedArrowDownKey

                            Just "ArrowUp" ->
                                UserPressedArrowUpKey

                            Just "Escape" ->
                                UserClearedInput

                            _ ->
                                NoOp
                    )
                ]
                [ Accessibility.inputText
                    (case model.value of
                        InputText search ->
                            search

                        SelectedSuggestion suggestion ->
                            Mapbox.name suggestion
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
                    , Attributes.class "grid p-2 border border-solid outline-none focus-visible:ring-4 border-neutral-500 placeholder:text-neutral-500 focus-visible:ring-accent-600"
                    ]
                ]
            )
        , Html.div
            [ Role.listBox
            , Attributes.id listboxId
            , Attributes.class "relative w-fulll"
            ]
            [ Html.div
                [ Attributes.class "w-full absolute h-0 bg-white border border-solid shadow-md opacity-0 group transition-[height,_opacity] overflow-clip transition-discrete border-neutral-500"
                , Attributes.classList
                    [ ( "opacity-100 h-[calc-size(auto,_size)]", isExpanded ) ]
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
                                            [ liFocusManager { hasFocus = hasFocus }
                                                [ Html.Events.Extra.onKeyDown
                                                    (\key ->
                                                        case key of
                                                            Just "ArrowDown" ->
                                                                UserPressedArrowDownKey

                                                            Just "ArrowUp" ->
                                                                UserPressedArrowUpKey

                                                            Just "ArrowLeft" ->
                                                                UserPressedArrowLeftKey

                                                            Just "ArrowRight" ->
                                                                UserPressedArrowRightKey

                                                            Just "Escape" ->
                                                                UserFocused Input

                                                            Just " " ->
                                                                NoOp

                                                            Just k ->
                                                                case String.uncons k of
                                                                    Just ( char, "" ) ->
                                                                        UserPressedPrintableCharacterKey char

                                                                    _ ->
                                                                        NoOp

                                                            _ ->
                                                                NoOp
                                                    )
                                                ]
                                                [ Html.button
                                                    [ Attributes.class "p-2 w-full outline-none focus:text-white active:transition-colors text-start group-hover:not-hover:focus:bg-neutral-600 hover:not-focus:bg-neutral-300 focus:bg-neutral-700 active:bg-neutral-800"
                                                    , Attributes.tabindex -1
                                                    , Events.onBlur (UserBlurred (Listbox { index = i }))
                                                    , Events.onFocus (UserFocused (Listbox { index = i }))
                                                    , Events.onClick (UserSelectedSuggestion suggestion)
                                                    ]
                                                    [ Html.div [ Attributes.class "line-clamp-1 text-ellipsis" ]
                                                        [ Html.text (Mapbox.name suggestion) ]
                                                    , Html.div
                                                        [ Attributes.class "line-clamp-1 text-ellipsis text-sm" ]
                                                        [ Html.text (Mapbox.placeFormatted suggestion) ]
                                                    ]
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
            ]
        , Html.div
            [ Attributes.class "sr-only"
            , Live.polite
            , Role.status
            ]
            [-- TODO: Implement live region
            ]
        ]


liFocusManager :
    { hasFocus : Bool }
    -> List (Attribute Msg)
    -> List (Html Msg)
    -> Html Msg
liFocusManager props attributes =
    Html.node "li-focus-manager"
        ([ Attributes.attribute "has-focus"
            (if props.hasFocus then
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


inputFocusManager :
    { hasFocus : Bool, cursorAction : Maybe CursorAction }
    -> List (Attribute Msg)
    -> List (Html Msg)
    -> Html Msg
inputFocusManager props attributes =
    Html.node "input-focus-manager"
        ([ Attributes.attribute "has-focus"
            (if props.hasFocus then
                "true"

             else
                ""
            )
         , case props.cursorAction of
            Just MoveLeft ->
                Attributes.attribute "cursor-action" "left"

            Just MoveRight ->
                Attributes.attribute "cursor-action" "right"

            Nothing ->
                Attributes.attribute "cursor-action" ""
         , Events.custom "reset"
            (Decode.succeed
                { message = ResetCursorAction
                , stopPropagation = False
                , preventDefault = False
                }
            )
         ]
            ++ attributes
        )
