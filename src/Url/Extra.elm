module Url.Extra exposing (decoder)

import Json.Decode as Decode exposing (Decoder)
import Url exposing (Url)


decoder : Decoder Url
decoder =
    Decode.string
        |> Decode.andThen
            (\urlString ->
                case Url.fromString urlString of
                    Just url ->
                        Decode.succeed url

                    Nothing ->
                        Decode.fail ("Invalid URL: " ++ urlString)
            )
