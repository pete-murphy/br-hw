module MapboxGl exposing
    ( MapView
    , Marker
    , view
    )

import Api.Coordinates as Coordinates exposing (Coordinates)
import Html exposing (Attribute, Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode


type alias MapView =
    { center : Coordinates
    , bounds : ( Coordinates, Coordinates )
    }


type alias Marker =
    { id : String
    , latitude : Float
    , longitude : Float
    }


encodeMarker : Marker -> Json.Encode.Value
encodeMarker marker =
    Json.Encode.object
        [ ( "id", Json.Encode.string marker.id )
        , ( "latitude", Json.Encode.float marker.latitude )
        , ( "longitude", Json.Encode.float marker.longitude )
        ]


decodeMapViewDetail : Decode.Decoder MapView
decodeMapViewDetail =
    Decode.field "detail"
        (Decode.succeed MapView
            |> Pipeline.required "center"
                (Decode.list Decode.float
                    |> Decode.andThen
                        (\list ->
                            case list of
                                [ lon, lat ] ->
                                    Decode.succeed { latitude = lat, longitude = lon }

                                _ ->
                                    Decode.fail "Invalid coordinates"
                        )
                )
            |> Pipeline.required "bounds"
                (Decode.list (Decode.list Decode.float)
                    |> Decode.andThen
                        (\list ->
                            case list of
                                [ [ swLon, swLat ], [ neLon, neLat ] ] ->
                                    Decode.succeed
                                        ( Coordinates swLat swLon
                                        , Coordinates neLat neLon
                                        )

                                _ ->
                                    Decode.fail "Invalid coordinates"
                        )
                )
        )


view :
    { center : Maybe Coordinates
    , onMove : MapView -> msg
    , markers : List Marker
    , highlightedMarker : Maybe String
    , onMarkerMouseEnter : String -> msg
    , onMarkerMouseLeave : String -> msg
    , accessToken : String
    }
    -> Html msg
view props =
    Html.node "mapbox-gl"
        [ case props.center of
            Nothing ->
                Attributes.class ""

            Just coordinates ->
                centerAttribute coordinates
        , Attributes.class "grid w-full h-full **:[.mapboxgl-marker]:!transition-colors **:[[data-highlighted=true]]:text-accent-dark **:[[data-highlighted=true]]:z-10 **:[[data-highlighted=false]]:text-gray-900/25"
        , Events.on "load" (decodeMapViewDetail |> Decode.map props.onMove)
        , Events.on "moveend" (decodeMapViewDetail |> Decode.map props.onMove)
        , markersAttribute props.markers
        , highlightedMarkerAttribute props.highlightedMarker
        , Events.on "marker-mouseenter" (Decode.at [ "detail", "id" ] Decode.string |> Decode.map props.onMarkerMouseEnter)
        , Events.on "marker-mouseleave" (Decode.at [ "detail", "id" ] Decode.string |> Decode.map props.onMarkerMouseLeave)
        , Attributes.attribute "access-token" props.accessToken

        -- , Events.on "zoomend" (decodeMapViewDetail |> Decode.map props.onMove)
        ]
        []


centerAttribute : Coordinates -> Attribute msg
centerAttribute coordinates =
    let
        json =
            Json.Encode.encode 0 (Coordinates.encode coordinates)
    in
    Attributes.attribute "center" json


markersAttribute : List Marker -> Attribute msg
markersAttribute markers =
    let
        json =
            Json.Encode.encode 0 (Json.Encode.list encodeMarker markers)
    in
    Attributes.attribute "markers" json


highlightedMarkerAttribute : Maybe String -> Attribute msg
highlightedMarkerAttribute highlightedMarker =
    case highlightedMarker of
        Nothing ->
            Attributes.attribute "highlighted-marker" (Json.Encode.encode 0 (Json.Encode.string ""))

        Just id ->
            Attributes.attribute "highlighted-marker" (Json.Encode.encode 0 (Json.Encode.string id))
