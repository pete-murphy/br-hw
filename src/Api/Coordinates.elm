module Api.Coordinates exposing
    ( Coordinates
    , attribute
    , decoder
    , encode
    )

import Html exposing (Attribute)
import Html.Attributes
import Json.Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode


type alias Coordinates =
    { latitude : Float
    , longitude : Float
    }



-- JSON


encode : Coordinates -> Json.Encode.Value
encode { latitude, longitude } =
    Json.Encode.object
        [ ( "latitude", Json.Encode.float latitude )
        , ( "longitude", Json.Encode.float longitude )
        ]


decoder : Json.Decode.Decoder Coordinates
decoder =
    Json.Decode.succeed Coordinates
        |> Pipeline.required "latitude" Json.Decode.float
        |> Pipeline.required "longitude" Json.Decode.float



-- HTML


attribute : Coordinates -> Attribute msg
attribute coordinates =
    let
        json =
            Json.Encode.encode 0 (encode coordinates)
    in
    Html.Attributes.attribute "coordinates" json
