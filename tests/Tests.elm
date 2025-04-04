module Tests exposing (..)

import Api.Boobook
import Test exposing (Test)


suite : Test
suite =
    Test.concat
        [ Api.Boobook.testSuite
        ]
