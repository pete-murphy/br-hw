module MapboxGl exposing (view)

import Api.Coordinates as Coordinates exposing (Coordinates)
import Html exposing (Html)


view :
    { center : Coordinates
    }
    -> Html msg
view props =
    Html.node "mapbox-gl"
        [ Coordinates.attribute props.center ]
        []
