module ApiData exposing
    ( ApiData
    , Value(..)
    , concatMap
    , fail
    , fromResult
    , get
    , getWith
    , isLoading
    , loading
    , map
    , notAsked
    , succeed
    , toLoading
    , toMaybe
    , traverseList
    , unwrap
    , value
    , withDefault
    )

import Dict
import Http


type ApiData a
    = ApiData (Internals a)


type alias Internals a =
    { value : Value a
    , isLoading : Bool
    }


type Value a
    = Empty
    | HttpError Http.Error
    | Success a



-- CONSTRUCTORS


notAsked : ApiData a
notAsked =
    ApiData { value = Empty, isLoading = False }


loading : ApiData a
loading =
    ApiData { value = Empty, isLoading = True }


succeed : a -> ApiData a
succeed a =
    ApiData { value = Success a, isLoading = False }


fail : Http.Error -> ApiData a
fail error =
    ApiData { value = HttpError error, isLoading = False }


fromResult : Result Http.Error a -> ApiData a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err error ->
            fail error



-- COMBINATORS


mapLoading : (Bool -> Bool) -> ApiData a -> ApiData a
mapLoading f (ApiData internals) =
    ApiData { internals | isLoading = f internals.isLoading }


toLoading : ApiData a -> ApiData a
toLoading =
    mapLoading (\_ -> True)


map : (a -> b) -> ApiData a -> ApiData b
map f (ApiData internals) =
    ApiData
        (case internals.value of
            Empty ->
                { value = Empty, isLoading = internals.isLoading }

            HttpError error ->
                { value = HttpError error, isLoading = internals.isLoading }

            Success a ->
                { value = Success (f a), isLoading = internals.isLoading }
        )


traverseList : (a -> ApiData b) -> List a -> ApiData (List b)
traverseList f =
    List.foldl
        (\a (ApiData acc) ->
            let
                data =
                    f a
            in
            case ( value data, acc.value ) of
                ( Success b, Success bs ) ->
                    ApiData { value = Success (b :: bs), isLoading = acc.isLoading || isLoading data }

                ( HttpError error, _ ) ->
                    fail error

                ( _, HttpError error ) ->
                    fail error

                ( _, _ ) ->
                    ApiData { value = Empty, isLoading = acc.isLoading || isLoading data }
        )
        (succeed [])


concatMap : (a -> ApiData b) -> ApiData a -> ApiData b
concatMap f (ApiData data) =
    -- TODO: Is this lawful? 🥴
    (case data.value of
        Success a ->
            f a

        HttpError err ->
            fail err

        Empty ->
            notAsked
    )
        |> mapLoading (\_ -> data.isLoading)



-- DESTRUCTORS


withDefault : a -> ApiData a -> a
withDefault default (ApiData internals) =
    case internals.value of
        Success a ->
            a

        _ ->
            default


toMaybe : ApiData a -> Maybe a
toMaybe (ApiData internals) =
    case internals.value of
        Success a ->
            Just a

        _ ->
            Nothing


value : ApiData a -> Value a
value (ApiData internals) =
    internals.value


isLoading : ApiData a -> Bool
isLoading (ApiData internals) =
    internals.isLoading


unwrap : ApiData a -> Internals a
unwrap (ApiData data) =
    data



-- DICT


getWith : (k -> dict -> Maybe (ApiData a)) -> k -> dict -> ApiData a
getWith getter key dict =
    getter key dict |> Maybe.withDefault notAsked


get : comparable -> Dict.Dict comparable (ApiData a) -> ApiData a
get =
    getWith Dict.get
