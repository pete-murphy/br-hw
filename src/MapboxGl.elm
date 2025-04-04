module MapboxGl exposing
    ( MapView
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
    }
    -> Html msg
view props =
    Html.node "mapbox-gl"
        [ case props.center of
            Nothing ->
                Attributes.class ""

            Just coordinates ->
                centerAttribute coordinates
        , Attributes.class "grid w-full h-full"
        , Events.on "load" (decodeMapViewDetail |> Decode.map props.onMove)
        , Events.on "moveend" (decodeMapViewDetail |> Decode.map props.onMove)

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
