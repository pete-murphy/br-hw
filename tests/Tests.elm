module Tests exposing (..)

import Api.Boobook
import Api.Coordinates
import Test exposing (Test)


suite : Test
suite =
    Test.concat
        [ Api.Boobook.testSuite
        , Api.Coordinates.testSuite
        ]
