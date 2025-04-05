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
import ApiData exposing (ApiData)
import Cmd.Extra
import Debouncer exposing (Debouncer)
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Html.Events.Extra
import Http
import Json.Decode as Decode
import Svg
import Svg.Attributes


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
    , searchResults : ApiData { search : String, results : List (Mapbox.Feature Mapbox.Suggestion) }
    , pendingRequestId : Maybe String
    , debouncer : Debouncer String
    , focus : Focus
    , cursorAction : Maybe CursorAction
    }


init : Model
init =
    { value = InputText ""
    , searchResults = ApiData.notAsked
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
                            ApiData.notAsked

                        _ ->
                            ApiData.toLoading model.searchResults
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
            case ApiData.value (model.searchResults |> ApiData.map .results) of
                ApiData.Success [] ->
                    ( model, Cmd.none, Nothing )

                ApiData.Success filteredOptions ->
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
                { model
                    | searchResults =
                        ApiData.fromResult result
                            |> ApiData.map
                                (\results -> { search = searchTerm, results = results })
                }

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
                , searchResults = ApiData.notAsked
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
            case ( ApiData.value model.searchResults, model.focus, model.value ) of
                ( ApiData.Empty, _, _ ) ->
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
    Html.node "search"
        [ Attributes.class "grid gap-2 p-2" ]
        [ Accessibility.labelBefore [ Attributes.class "grid gap-2 peer" ]
            (Html.h1
                [ Attributes.class "px-4 text-sm font-semibold tracking-widest uppercase"
                ]
                [ Html.text "Find in-store" ]
            )
            (Html.div
                [ Attributes.class "grid p-2 border border-solid ring-transparent border-grey-600 grid-cols-[1fr_auto] ring-3 has-focus-visible:ring-accent hover:ring-accent/25"
                ]
                [ inputFocusManager
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
                        , Attributes.class "grid p-2 outline-none placeholder:text-grey-400"
                        ]
                    ]
                , Html.div [ Attributes.class "grid items-center p-2" ]
                    (if ApiData.isLoading model.searchResults then
                        [ Svg.svg
                            [ Svg.Attributes.viewBox "0 0 24 24"
                            , Svg.Attributes.fill "currentColor"
                            , Svg.Attributes.class "size-6"
                            , Svg.Attributes.class "animate-spin text-grey-400"
                            ]
                            [ Svg.path
                                [ Svg.Attributes.fillRule "evenodd"
                                , Svg.Attributes.d "M4.755 10.059a7.5 7.5 0 0 1 12.548-3.364l1.903 1.903h-3.183a.75.75 0 1 0 0 1.5h4.992a.75.75 0 0 0 .75-.75V4.356a.75.75 0 0 0-1.5 0v3.18l-1.9-1.9A9 9 0 0 0 3.306 9.67a.75.75 0 1 0 1.45.388Zm15.408 3.352a.75.75 0 0 0-.919.53 7.5 7.5 0 0 1-12.548 3.364l-1.902-1.903h3.183a.75.75 0 0 0 0-1.5H2.984a.75.75 0 0 0-.75.75v4.992a.75.75 0 0 0 1.5 0v-3.18l1.9 1.9a9 9 0 0 0 15.059-4.035.75.75 0 0 0-.53-.918Z"
                                , Svg.Attributes.clipRule "evenodd"
                                ]
                                []
                            ]
                        ]

                     else
                        [ Svg.svg
                            [ Svg.Attributes.viewBox "0 0 24 24"
                            , Svg.Attributes.fill "currentColor"
                            , Svg.Attributes.class "size-6"
                            ]
                            [ Svg.path
                                [ Svg.Attributes.fillRule "evenodd"
                                , Svg.Attributes.d "M10.5 3.75a6.75 6.75 0 1 0 0 13.5 6.75 6.75 0 0 0 0-13.5ZM2.25 10.5a8.25 8.25 0 1 1 14.59 5.28l4.69 4.69a.75.75 0 1 1-1.06 1.06l-4.69-4.69A8.25 8.25 0 0 1 2.25 10.5Z"
                                , Svg.Attributes.clipRule "evenodd"
                                ]
                                []
                            ]
                        ]
                    )
                ]
            )
        , Html.div
            [ Role.listBox
            , Attributes.id listboxId
            , Attributes.class "relative z-10 w-full"
            ]
            [ Html.div
                [ Attributes.class "absolute w-full h-0 bg-white border border-solid shadow-md opacity-0 ease-out border-grey-600 group transition-[height,_opacity] overflow-clip transition-discrete"
                , Attributes.classList
                    [ ( "opacity-100 ease-in h-[calc-size(auto,_size)]", isExpanded ) ]
                ]
                [ case ( ApiData.value (model.searchResults |> ApiData.map .results), ApiData.isLoading model.searchResults ) of
                    ( ApiData.Success [], _ ) ->
                        Html.div [ Attributes.class "p-2" ]
                            [ Html.text "No results found" ]

                    ( ApiData.Success results, _ ) ->
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
                                                    [ Attributes.class "py-2 px-4 w-full outline-none focus:text-white active:transition-colors text-start group-hover:not-hover:focus:bg-grey-600 hover:not-focus:bg-grey-300 focus:bg-grey-600 active:bg-accent-dark"
                                                    , Attributes.tabindex -1
                                                    , Events.onBlur (UserBlurred (Listbox { index = i }))
                                                    , Events.onFocus (UserFocused (Listbox { index = i }))
                                                    , Events.onClick (UserSelectedSuggestion suggestion)
                                                    ]
                                                    [ Html.div [ Attributes.class "line-clamp-1 text-ellipsis" ]
                                                        [ Html.text (Mapbox.name suggestion) ]
                                                    , Html.div
                                                        [ Attributes.class "text-sm line-clamp-1 text-ellipsis" ]
                                                        [ Html.text (Mapbox.placeFormatted suggestion) ]
                                                    ]
                                                ]
                                            ]
                                    )
                            )

                    ( ApiData.Empty, True ) ->
                        Html.div [ Attributes.class "p-2" ]
                            [ Html.text "Loading..." ]

                    ( ApiData.Empty, False ) ->
                        Html.div [ Attributes.class "p-2 h-[1lh]" ]
                            [ Html.text "" ]

                    ( ApiData.HttpError _, _ ) ->
                        Html.div [ Attributes.class "p-2" ]
                            [ Html.text "Something went wrong!" ]
                ]
            ]
        , Html.div
            [ Attributes.class "sr-only"
            , Live.polite
            , Role.status
            ]
            [ Html.text
                (case ApiData.value model.searchResults of
                    ApiData.Success { results, search } ->
                        if results == [] then
                            "No search results found for " ++ search

                        else
                            "Found " ++ String.fromInt (List.length results) ++ " results for " ++ search

                    _ ->
                        ""
                )
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
