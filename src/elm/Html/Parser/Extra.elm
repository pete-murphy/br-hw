module Html.Parser.Extra exposing (decoder)

import Html.Parser
import Json.Decode as Decode


decoder : Decode.Decoder (List Html.Parser.Node)
decoder =
    Decode.string
        |> Decode.andThen
            (\string ->
                case Html.Parser.run string of
                    Ok nodes ->
                        Decode.succeed nodes

                    Err _ ->
                        Decode.fail "Failed to parse HTML"
            )
