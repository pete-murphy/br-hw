module Html.Events.Extra exposing (onKeyDown)

import Html exposing (Attribute)
import Html.Events
import Json.Decode


onKeyDown : (Maybe String -> msg) -> Attribute msg
onKeyDown handle =
    Html.Events.stopPropagationOn "keydown"
        (Json.Decode.field "key" (Json.Decode.maybe Json.Decode.string)
            |> Json.Decode.map (\str -> ( handle str, True ))
        )
