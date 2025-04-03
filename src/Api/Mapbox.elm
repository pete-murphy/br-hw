module Api.Mapbox exposing (Suggestion, getSuggestions)

import Http
import Json.Decode
import Json.Decode.Pipeline as Pipeline
import Url.Builder exposing (QueryParameter(..))


type alias Suggestion =
    { name : String
    , mapboxId : String
    , address : Maybe String
    , fullAddress : Maybe String
    , placeFormatted : String
    }


suggestionDecoder : Json.Decode.Decoder Suggestion
suggestionDecoder =
    Json.Decode.succeed Suggestion
        |> Pipeline.required "name" Json.Decode.string
        |> Pipeline.required "mapbox_id" Json.Decode.string
        |> Pipeline.optional "address" (Json.Decode.nullable Json.Decode.string) Nothing
        |> Pipeline.optional "full_address" (Json.Decode.nullable Json.Decode.string) Nothing
        |> Pipeline.required "place_formatted" Json.Decode.string


responseDecoder : Json.Decode.Decoder (List Suggestion)
responseDecoder =
    Json.Decode.field "suggestions" (Json.Decode.list suggestionDecoder)


builder =
    Url.Builder.crossOrigin "https://api.mapbox.com"


getSuggestions :
    { mapboxAccessToken : String
    , mapboxSessionToken : String
    , query : String
    }
    -> (Result Http.Error (List Suggestion) -> msg)
    -> Cmd msg
getSuggestions params mkMsg =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Content-Type" "application/json"
            ]
        , url =
            builder
                [ "search"
                , "searchbox"
                , "v1"
                , "suggest"
                ]
                [ Url.Builder.string "q" params.query
                , Url.Builder.string "limit" "10"
                , Url.Builder.string "language" "en"
                , Url.Builder.string "session_token" params.mapboxSessionToken
                , Url.Builder.string "access_token" params.mapboxAccessToken
                , Url.Builder.string "types" "country,region,postcode,district,place,city,locality,neighborhood,street,address"
                ]
        , body = Http.emptyBody
        , tracker = Just params.query
        , timeout = Nothing
        , expect =
            Http.expectJson mkMsg responseDecoder
        }


responseJson : String
responseJson =
    """
{
  "suggestions": [
    {
      "name": "East Broadway",
      "mapbox_id": "dXJuOm1ieGFkci1zdHI6MjRhY2RkMTktMTRjMi00OTUzLTlhZmItZmVkN2M5ZDQ1MDU4",
      "feature_type": "street",
      "place_formatted": "South Boston, Massachusetts 02127, United States",
      "context": {
        "country": {
          "id": "dXJuOm1ieHBsYzpJdXc",
          "name": "United States",
          "country_code": "US",
          "country_code_alpha_3": "USA"
        },
        "region": {
          "id": "dXJuOm1ieHBsYzpCV1Rz",
          "name": "Massachusetts",
          "region_code": "MA",
          "region_code_full": "US-MA"
        },
        "postcode": { "id": "dXJuOm1ieHBsYzpOdzdz", "name": "02127" },
        "district": {
          "id": "dXJuOm1ieHBsYzpBVk9tN0E",
          "name": "Suffolk County"
        },
        "place": { "id": "dXJuOm1ieHBsYzpFbFdvN0E", "name": "South Boston" },
        "street": {
          "id": "dXJuOm1ieGFkci1zdHI6MjRhY2RkMTktMTRjMi00OTUzLTlhZmItZmVkN2M5ZDQ1MDU4",
          "name": "East Broadway"
        }
      },
      "language": "en",
      "maki": "marker",
      "metadata": {},
      "distance": 23815
    },
    {
      "name": "East Broadway",
      "mapbox_id": "dXJuOm1ieGFkci1zdHI6NTdjOGYwNjYtNjFjYS00MTRjLThhODQtNjhjMTZkODk2M2M1",
      "feature_type": "street",
      "place_formatted": "Haverhill, Massachusetts 01830, United States",
      "context": {
        "country": {
          "id": "dXJuOm1ieHBsYzpJdXc",
          "name": "United States",
          "country_code": "US",
          "country_code_alpha_3": "USA"
        },
        "region": {
          "id": "dXJuOm1ieHBsYzpCV1Rz",
          "name": "Massachusetts",
          "region_code": "MA",
          "region_code_full": "US-MA"
        },
        "postcode": { "id": "dXJuOm1ieHBsYzpKdTdz", "name": "01830" },
        "district": { "id": "dXJuOm1ieHBsYzpieWJz", "name": "Essex County" },
        "place": { "id": "dXJuOm1ieHBsYzpDSS9JN0E", "name": "Haverhill" },
        "street": {
          "id": "dXJuOm1ieGFkci1zdHI6NTdjOGYwNjYtNjFjYS00MTRjLThhODQtNjhjMTZkODk2M2M1",
          "name": "East Broadway"
        }
      },
      "language": "en",
      "maki": "marker",
      "metadata": {},
      "distance": 52208
    },
    {
      "name": "East Broadway",
      "mapbox_id": "dXJuOm1ieGFkci1zdHI6ZTQ2YWIwM2YtOWRkZC00ZGYxLWIzZDMtMTNjOTc0OTI3NDhl",
      "feature_type": "street",
      "place_formatted": "Taunton, Massachusetts 02780, United States",
      "context": {
        "country": {
          "id": "dXJuOm1ieHBsYzpJdXc",
          "name": "United States",
          "country_code": "US",
          "country_code_alpha_3": "USA"
        },
        "region": {
          "id": "dXJuOm1ieHBsYzpCV1Rz",
          "name": "Massachusetts",
          "region_code": "MA",
          "region_code_full": "US-MA"
        },
        "postcode": { "id": "dXJuOm1ieHBsYzpWazdz", "name": "02780" },
        "district": { "id": "dXJuOm1ieHBsYzpJa2Jz", "name": "Bristol County" },
        "place": { "id": "dXJuOm1ieHBsYzpFMGNJN0E", "name": "Taunton" },
        "street": {
          "id": "dXJuOm1ieGFkci1zdHI6ZTQ2YWIwM2YtOWRkZC00ZGYxLWIzZDMtMTNjOTc0OTI3NDhl",
          "name": "East Broadway"
        }
      },
      "language": "en",
      "maki": "marker",
      "metadata": {},
      "distance": 58016
    },
    {
      "name": "E Broadway",
      "mapbox_id": "dXJuOm1ieGFkci1zdHI6NjZlMjUyN2QtMzVmMS00NjA5LTkzZWQtZWRmZmEwMDlkNGM1",
      "feature_type": "street",
      "place_formatted": "Attleboro, Massachusetts 02780, United States",
      "context": {
        "country": {
          "id": "dXJuOm1ieHBsYzpJdXc",
          "name": "United States",
          "country_code": "US",
          "country_code_alpha_3": "USA"
        },
        "region": {
          "id": "dXJuOm1ieHBsYzpCV1Rz",
          "name": "Massachusetts",
          "region_code": "MA",
          "region_code_full": "US-MA"
        },
        "postcode": { "id": "dXJuOm1ieHBsYzpWazdz", "name": "02780" },
        "district": { "id": "dXJuOm1ieHBsYzpJa2Jz", "name": "Bristol County" },
        "place": { "id": "dXJuOm1ieHBsYzoxZ2pz", "name": "Attleboro" },
        "street": {
          "id": "dXJuOm1ieGFkci1zdHI6NjZlMjUyN2QtMzVmMS00NjA5LTkzZWQtZWRmZmEwMDlkNGM1",
          "name": "E Broadway"
        }
      },
      "language": "en",
      "maki": "marker",
      "metadata": {},
      "distance": 63525
    },
    {
      "name": "East Broadway",
      "mapbox_id": "dXJuOm1ieGFkci1zdHI6OTU5MmRjMDMtYTA5OC00Mzc5LWJhZGUtNzMxNzc4MGQ5NGZk",
      "feature_type": "street",
      "place_formatted": "Salem, New Hampshire 03079, United States",
      "context": {
        "country": {
          "id": "dXJuOm1ieHBsYzpJdXc",
          "name": "United States",
          "country_code": "US",
          "country_code_alpha_3": "USA"
        },
        "region": {
          "id": "dXJuOm1ieHBsYzpCVVRz",
          "name": "New Hampshire",
          "region_code": "NH",
          "region_code_full": "US-NH"
        },
        "postcode": { "id": "dXJuOm1ieHBsYzpaZzdz", "name": "03079" },
        "district": {
          "id": "dXJuOm1ieHBsYzpBVExHN0E",
          "name": "Rockingham County"
        },
        "place": { "id": "dXJuOm1ieHBsYzpFVStvN0E", "name": "Salem" },
        "neighborhood": {
          "id": "dXJuOm1ieHBsYzovT3pz",
          "name": "Arlington Park"
        },
        "street": {
          "id": "dXJuOm1ieGFkci1zdHI6OTU5MmRjMDMtYTA5OC00Mzc5LWJhZGUtNzMxNzc4MGQ5NGZk",
          "name": "East Broadway"
        }
      },
      "language": "en",
      "maki": "marker",
      "metadata": {},
      "distance": 65226
    }
  ],
  "attribution": "© 2025 Mapbox and its suppliers. All rights reserved. Use of this data is subject to the Mapbox Terms of Service. (https://www.mapbox.com/about/maps/)",
  "response_id": "dvCsu_xXi66rMTotPSVuv-BpZZ9hSm0IUTDrnXFEl9dA61bLuf1DKjx5YZdJ419ks11ZfQ6BJCvnqvXexmdXj5o4SxKo1U4T4mmQ"
}
"""
