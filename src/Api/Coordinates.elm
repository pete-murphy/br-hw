module Api.Coordinates exposing
    ( Coordinates
    , decoder
    , distanceInKm
    , encode
    , testSuite
    )

import Expect
import Json.Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode
import Test exposing (Test)


type alias Coordinates =
    { latitude : Float
    , longitude : Float
    }


type Bounds
    = Bounds
        { southwest : Coordinates
        , northeast : Coordinates
        }


isInBounds : Coordinates -> Bounds -> Bool
isInBounds coordinates (Bounds { southwest, northeast }) =
    coordinates.latitude
        >= southwest.latitude
        && coordinates.latitude
        <= northeast.latitude
        && coordinates.longitude
        >= southwest.longitude
        && coordinates.longitude
        <= northeast.longitude


distanceInKm : Coordinates -> Coordinates -> Float
distanceInKm x y =
    let
        lat1 =
            x.latitude

        lon1 =
            x.longitude

        lat2 =
            y.latitude

        lon2 =
            y.longitude

        dLat =
            (lat2 - lat1) * (pi / 180)

        dLon =
            (lon2 - lon1) * (pi / 180)

        a =
            sin (dLat / 2) ^ 2 + cos (lat1 * (pi / 180)) * cos (lat2 * (pi / 180)) * sin (dLon / 2) ^ 2

        c =
            2 * atan2 (sqrt a) (sqrt (1 - a))

        r =
            -- Radius of Earth in kilometers
            6371
    in
    r * c



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



-- TEST


testSuite : Test
testSuite =
    Test.describe "Coordinates"
        [ Test.describe "isInBounds"
            [ Test.test "returns True when coordinates are inside bounds" <|
                \_ ->
                    let
                        bounds =
                            Bounds
                                { southwest = { latitude = 0, longitude = 0 }
                                , northeast = { latitude = 10, longitude = 10 }
                                }

                        point =
                            { latitude = 5, longitude = 5 }
                    in
                    isInBounds point bounds
                        |> Expect.equal True
            , Test.test "returns False when coordinates are north of bounds" <|
                \_ ->
                    let
                        bounds =
                            Bounds
                                { southwest = { latitude = 0, longitude = 0 }
                                , northeast = { latitude = 10, longitude = 10 }
                                }

                        point =
                            { latitude = 15, longitude = 5 }
                    in
                    isInBounds point bounds
                        |> Expect.equal False
            , Test.test "returns False when coordinates are south of bounds" <|
                \_ ->
                    let
                        bounds =
                            Bounds
                                { southwest = { latitude = 0, longitude = 0 }
                                , northeast = { latitude = 10, longitude = 10 }
                                }

                        point =
                            { latitude = -5, longitude = 5 }
                    in
                    isInBounds point bounds
                        |> Expect.equal False
            , Test.test "returns False when coordinates are east of bounds" <|
                \_ ->
                    let
                        bounds =
                            Bounds
                                { southwest = { latitude = 0, longitude = 0 }
                                , northeast = { latitude = 10, longitude = 10 }
                                }

                        point =
                            { latitude = 5, longitude = 15 }
                    in
                    isInBounds point bounds
                        |> Expect.equal False
            , Test.test "returns False when coordinates are west of bounds" <|
                \_ ->
                    let
                        bounds =
                            Bounds
                                { southwest = { latitude = 0, longitude = 0 }
                                , northeast = { latitude = 10, longitude = 10 }
                                }

                        point =
                            { latitude = 5, longitude = -5 }
                    in
                    isInBounds point bounds
                        |> Expect.equal False
            , Test.test "returns True when coordinates are exactly on bounds corner" <|
                \_ ->
                    let
                        bounds =
                            Bounds
                                { southwest = { latitude = 0, longitude = 0 }
                                , northeast = { latitude = 10, longitude = 10 }
                                }

                        point =
                            { latitude = 0, longitude = 0 }
                    in
                    isInBounds point bounds
                        |> Expect.equal True
            ]
        , Test.describe "distanceInKm"
            [ Test.test "calculates distance between London and Paris" <|
                \_ ->
                    let
                        london =
                            { latitude = 51.5074, longitude = -0.1278 }

                        paris =
                            { latitude = 48.8566, longitude = 2.3522 }

                        distance =
                            distanceInKm london paris
                    in
                    Expect.all
                        [ \d -> Expect.greaterThan 340 d
                        , \d -> Expect.lessThan 350 d
                        ]
                        distance
            ]
        ]
