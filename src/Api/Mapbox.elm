module Api.Mapbox exposing
    ( Feature
    , Retrieved
    , Suggestion
    , address
    , coordinates
    , fullAddress
    , mapboxId
    , maybePlaceFormatted
    , name
    , placeFormatted
    , coordinatesAttribute
    , getSuggestions
    , retrieveSuggestion
    )

{-|


# TYPES

@docs Feature
@docs Retrieved
@docs Suggestion


# GETTERS

@docs address
@docs coordinates
@docs fullAddress
@docs mapboxId
@docs maybePlaceFormatted
@docs name
@docs placeFormatted


# HTML

@docs coordinatesAttribute


# HTTP

@docs getSuggestions
@docs retrieveSuggestion

-}

import Html exposing (Attribute)
import Html.Attributes
import Http
import Json.Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode
import Url.Builder exposing (QueryParameter(..))


type Feature a
    = Feature Internals a


type alias Internals =
    { name : String
    , mapboxId : String
    , address : Maybe String
    , fullAddress : Maybe String
    }


type alias Suggestion =
    { placeFormatted : String }


type alias Retrieved =
    { coordinates : Coordinates
    , placeFormatted : Maybe String
    }


type alias Coordinates =
    { latitude : Float
    , longitude : Float
    }



-- GETTERS


name : Feature a -> String
name (Feature internals _) =
    internals.name


mapboxId : Feature a -> String
mapboxId (Feature internals _) =
    internals.mapboxId


address : Feature a -> Maybe String
address (Feature internals _) =
    internals.address


fullAddress : Feature a -> Maybe String
fullAddress (Feature internals _) =
    internals.fullAddress


placeFormatted : Feature Suggestion -> String
placeFormatted (Feature _ suggestion) =
    suggestion.placeFormatted


maybePlaceFormatted : Feature Retrieved -> Maybe String
maybePlaceFormatted (Feature _ suggestion) =
    suggestion.placeFormatted


coordinates : Feature Retrieved -> Coordinates
coordinates (Feature _ suggestion) =
    suggestion.coordinates



-- DECODERS


internalsDecoder : Json.Decode.Decoder Internals
internalsDecoder =
    Json.Decode.succeed Internals
        |> Pipeline.required "name" Json.Decode.string
        |> Pipeline.required "mapbox_id" Json.Decode.string
        |> Pipeline.optional "address" (Json.Decode.nullable Json.Decode.string) Nothing
        |> Pipeline.optional "full_address" (Json.Decode.nullable Json.Decode.string) Nothing


suggestionDecoder : Json.Decode.Decoder Suggestion
suggestionDecoder =
    Json.Decode.succeed Suggestion
        |> Pipeline.required "place_formatted" Json.Decode.string


suggestionFeatureDecoder : Json.Decode.Decoder (Feature Suggestion)
suggestionFeatureDecoder =
    Json.Decode.succeed Feature
        |> Pipeline.custom internalsDecoder
        |> Pipeline.custom suggestionDecoder


coordinatesDecoder : Json.Decode.Decoder Coordinates
coordinatesDecoder =
    Json.Decode.succeed Coordinates
        |> Pipeline.required "latitude" Json.Decode.float
        |> Pipeline.required "longitude" Json.Decode.float


retrievedDecoder : Json.Decode.Decoder Retrieved
retrievedDecoder =
    Json.Decode.succeed Retrieved
        |> Pipeline.required "coordinates" coordinatesDecoder
        |> Pipeline.optional "place_formatted" (Json.Decode.nullable Json.Decode.string) Nothing


retrievedFeatureDecoder : Json.Decode.Decoder (Feature Retrieved)
retrievedFeatureDecoder =
    Json.Decode.succeed Feature
        |> Pipeline.custom internalsDecoder
        |> Pipeline.custom retrievedDecoder



-- HTML


coordinatesAttribute : Feature Retrieved -> Attribute msg
coordinatesAttribute (Feature _ retrieved) =
    let
        json =
            Json.Encode.encode 0
                (Json.Encode.object
                    [ ( "latitude", Json.Encode.float retrieved.coordinates.latitude )
                    , ( "longitude", Json.Encode.float retrieved.coordinates.longitude )
                    ]
                )
    in
    Html.Attributes.attribute "coordinates" json



-- HTTP


builder : List String -> List QueryParameter -> String
builder =
    Url.Builder.crossOrigin "https://api.mapbox.com"


getSuggestions :
    { mapboxAccessToken : String
    , mapboxSessionToken : String
    , query : String
    }
    -> (Result Http.Error (List (Feature Suggestion)) -> msg)
    -> Cmd msg
getSuggestions params mkMsg =
    let
        responseDecoder : Json.Decode.Decoder (List (Feature Suggestion))
        responseDecoder =
            Json.Decode.field "suggestions" (Json.Decode.list suggestionFeatureDecoder)
    in
    Http.request
        { method = "GET"
        , headers = []
        , url =
            builder
                [ "search"
                , "searchbox"
                , "v1"
                , "suggest"
                ]
                [ Url.Builder.string "q" params.query
                , Url.Builder.string "limit" "10"
                , Url.Builder.string "session_token" params.mapboxSessionToken
                , Url.Builder.string "access_token" params.mapboxAccessToken
                , Url.Builder.string "types" "country,region,postcode,district,place,city,locality,neighborhood,street,address"
                ]
        , body = Http.emptyBody
        , tracker = Just params.query
        , timeout = Nothing
        , expect =
            Http.expectJson mkMsg responseDecoder
        }


retrieveSuggestion :
    { mapboxAccessToken : String
    , mapboxSessionToken : String
    , mapboxId : String
    }
    -> (Result Http.Error (Feature Retrieved) -> msg)
    -> Cmd msg
retrieveSuggestion params mkMsg =
    let
        responseDecoder : Json.Decode.Decoder (Feature Retrieved)
        responseDecoder =
            Json.Decode.field "features"
                (Json.Decode.list (Json.Decode.field "properties" retrievedFeatureDecoder))
                |> Json.Decode.andThen
                    (\list ->
                        case list of
                            retrievedFeature :: _ ->
                                Json.Decode.succeed retrievedFeature

                            _ ->
                                Json.Decode.fail "Expected at least one feature"
                    )
    in
    Http.request
        { method = "GET"
        , headers = []
        , url =
            builder
                [ "search"
                , "searchbox"
                , "v1"
                , "retrieve"
                , params.mapboxId
                ]
                [ Url.Builder.string "session_token" params.mapboxSessionToken
                , Url.Builder.string "access_token" params.mapboxAccessToken
                ]
        , body = Http.emptyBody
        , tracker = Nothing
        , timeout = Nothing
        , expect =
            Http.expectJson mkMsg responseDecoder
        }
