module MapboxGl exposing (view)

import Api.Coordinates as Coordinates exposing (Coordinates)
import Html exposing (Attribute, Html)
import Html.Attributes as Attributes
import Json.Encode


view :
    { center : Maybe Coordinates
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
        ]
        []


centerAttribute : Coordinates -> Attribute msg
centerAttribute coordinates =
    let
        json =
            Json.Encode.encode 0 (Coordinates.encode coordinates)
    in
    Attributes.attribute "center" json
