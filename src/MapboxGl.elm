module MapboxGl exposing (view)

import Api.Coordinates as Coordinates exposing (Coordinates)
import Html exposing (Attribute, Html)
import Html.Attributes as Attributes
import Json.Encode


view :
    { center : Coordinates
    }
    -> Html msg
view props =
    Html.node "mapbox-gl"
        [ centerAttribute props.center
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
