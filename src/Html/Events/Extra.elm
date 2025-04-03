module Html.Events.Extra exposing (onKeyDown)

import Html exposing (Attribute)
import Html.Events
import Json.Decode


decodeKey : String -> msg -> Json.Decode.Decoder msg
decodeKey key msg =
    Json.Decode.field "key" (Json.Decode.maybe Json.Decode.string)
        |> Json.Decode.andThen
            (\k ->
                if k == Just key then
                    Json.Decode.succeed msg

                else
                    Json.Decode.fail "Didn't match key"
            )


onKeyDown : List ( String, msg ) -> Attribute msg
onKeyDown handlers =
    Html.Events.stopPropagationOn "keydown"
        (Json.Decode.oneOf
            (List.map
                (\( key, msg ) -> decodeKey key msg)
                handlers
            )
            |> Json.Decode.map (\msg -> ( msg, True ))
        )
