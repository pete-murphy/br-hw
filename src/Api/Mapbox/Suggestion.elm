module Api.Mapbox.Suggestion exposing (..)


type alias Suggestion =
    { name : String
    , mapboxId : String
    , address : Maybe String
    , fullAddress : Maybe String
    , placeFormatted : String
    }


sampleSuggestions : List Suggestion
sampleSuggestions =
    [ { name = "1201 S Main St"
      , mapboxId = "Example ID 1"
      , address = Just "1201 S Main St"
      , fullAddress = Just "1201 S Main St, Ann Arbor, Michigan 48104, United States of America"
      , placeFormatted = "Ann Arbor, Michigan 48104, United States of America"
      }
    , { name = "120 S Main St"
      , mapboxId = "Example ID 2"
      , address = Just "120 S Main St"
      , fullAddress = Just "120 S Main St, Ann Arbor, Michigan 48104, United States of America"
      , placeFormatted = "Ann Arbor, Michigan 48104, United States of America"
      }
    , { name = "Juniper St"
      , mapboxId = "Example ID 3"
      , address = Just "Juniper St"
      , fullAddress = Just "Juniper St, Ann Arbor, Michigan 48104, United States of America"
      , placeFormatted = "Ann Arbor, Michigan 48104, United States of America"
      }
    ]



-- {
--   "name": "Michigan Stadium",
--   "mapbox_id": "Example ID",
--   "feature_type": "poi",
--   "address": "1201 S Main St",
--   "full_address": "1201 S Main St, Ann Arbor, Michigan 48104, United States of America",
--   "place_formatted": "Ann Arbor, Michigan 48104, United States of America",
--   "context": {
--     "country": {
--       "name": "United States of America",
--       "country_code": "US",
--       "country_code_alpha_3": "USA"
--     },
--     "region": {
--       "name": "Michigan",
--       "region_code": "MI",
--       "region_code_full": "US-MI"
--     },
--     "postcode": { "name": "48104" },
--     "place": { "name": "Ann Arbor" },
--     "neighborhood": { "name": "South Main" },
--     "street": { "name": "s main st" }
--   },
--   "language": "en",
--   "maki": "marker",
--   "poi_category": ["track", "sports"],
--   "poi_category_ids": ["track", "sports"],
--   "external_ids": {
--     "safegraph": "Example ID",
--     "foursquare": "Example ID"
--   },
--   "metadata": {}
-- }
