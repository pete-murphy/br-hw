module Api.Boobook exposing
    ( getNearby
    , testSuite
    )

import Expect
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Test exposing (Test)
import Url exposing (Url)
import Url.Builder exposing (QueryParameter(..))
import Url.Extra


type alias Response =
    { problems : List Decode.Value
    , retailers : List Retailer
    }


type alias Retailer =
    { address : String
    , distanceInKms : Float
    , id : String
    , latitude : Float
    , longitude : Float
    , name : String
    , phoneNumber : Maybe String
    , website : Maybe Url
    }



-- DECODERS


responseDecoder : Decode.Decoder Response
responseDecoder =
    Decode.succeed Response
        |> Pipeline.required "problems" (Decode.list Decode.value)
        |> Pipeline.required "retailers" (Decode.list retailerDecoder)


decodeDistanceInKms : Decode.Decoder Float
decodeDistanceInKms =
    Decode.string
        |> Decode.andThen
            (\str ->
                case List.map String.toFloat (String.split "\u{00A0}" str) of
                    [ Just distance, _ ] ->
                        Decode.succeed distance

                    [ Nothing, _ ] ->
                        Decode.fail "Invalid distance"

                    _ ->
                        Decode.fail "Missing \u{00A0}"
            )


retailerDecoder : Decode.Decoder Retailer
retailerDecoder =
    Decode.succeed Retailer
        |> Pipeline.required "address" Decode.string
        |> Pipeline.required "distance_in_kms" decodeDistanceInKms
        |> Pipeline.required "id" Decode.string
        |> Pipeline.required "latitude" Decode.float
        |> Pipeline.required "longitude" Decode.float
        |> Pipeline.required "name" Decode.string
        |> Pipeline.optional "phone_number" (Decode.maybe Decode.string) Nothing
        |> Pipeline.optional "website" (Decode.maybe Url.Extra.decoder) Nothing



-- HTTP


builder : List String -> List QueryParameter -> String
builder =
    Url.Builder.crossOrigin "https://production.retailers.boobook-services.com"


getNearby :
    { latitude : Float, longitude : Float, radius : Int }
    -> (Result Http.Error Response -> msg)
    -> Cmd msg
getNearby { latitude, longitude, radius } mkMsg =
    Http.request
        { method = "GET"
        , headers = []
        , url =
            builder
                [ "retailers", "nearby" ]
                [ Url.Builder.string "latitude" (String.fromFloat latitude)
                , Url.Builder.string "longitude" (String.fromFloat longitude)
                , Url.Builder.int "radius" radius
                ]
        , body = Http.emptyBody
        , tracker = Nothing
        , timeout = Nothing
        , expect = Http.expectJson mkMsg responseDecoder
        }



-- TESTS


testSuite : Test
testSuite =
    Test.describe "Boobook"
        [ Test.describe "decoder"
            [ Test.test "decodes sample JSON" <|
                \_ ->
                    let
                        decoded =
                            Decode.decodeString
                                responseDecoder
                                sampleJson
                    in
                    decoded
                        |> Expect.all
                            [ Result.map (.retailers >> List.length) >> Expect.equal (Ok 80)
                            , Result.map (.problems >> List.length) >> Expect.equal (Ok 0)
                            , Result.map (.retailers >> List.head >> Maybe.map .name)
                                >> Expect.equal (Ok (Just "Sault New England"))
                            , Result.map (.retailers >> List.head >> Maybe.map .name)
                                >> Expect.equal (Ok (Just "Sault New England"))
                            ]
            ]
        ]


sampleJson : String
sampleJson =
    """
{
  "problems": [],
  "retailers": [
    {
      "address": "577 Tremont St<br/>Boston, MA United States 2118",
      "distance_in_kms": "2.5784531497006618\u{00A0}km",
      "id": "9297090672014131307",
      "latitude": 42.3436128,
      "longitude": -71.0727815,
      "name": "Sault New England",
      "phone_number": "(857) 239-9434",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://saultne.com/search?type=product,article,page&q=bellroy"
    },
    {
      "address": "174 Newbury Street<br/>Boston, MA United States 2116",
      "distance_in_kms": "3.353884248962555\u{00A0}km",
      "id": "9297085000224604267",
      "latitude": 42.3503179,
      "longitude": -71.0790026,
      "name": "Rhone - Boston",
      "phone_number": "857-277-0875",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:54 UTC +00:00",
      "website": null
    },
    {
      "address": "1274 Washington Street<br/>West Newton, MA United States 2465",
      "distance_in_kms": "15.111503143057474\u{00A0}km",
      "id": "9297090713185419371",
      "latitude": 42.3492259,
      "longitude": -71.2258074,
      "name": "The Paper Mouse",
      "phone_number": "(617) 928-9898",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.thepapermouse.com/search?type=product,article,page&q=bellroy*"
    },
    {
      "address": "82 Thoreau St<br/>Concord, MA United States 1742",
      "distance_in_kms": "29.150314250797955\u{00A0}km",
      "id": "9297085041597218923",
      "latitude": 42.45685131,
      "longitude": -71.35744593,
      "name": "Juju",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "162 State Street\\n#3\\n<br/>Newburyport, MA United States 01950",
      "distance_in_kms": "53.63899805156413\u{00A0}km",
      "id": "10681961244031713483",
      "latitude": 42.802288,
      "longitude": -70.8746643,
      "name": "Edit Style Lounge",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "162 State Street\\n#3\\n<br/>Newburyport, MA United States 01950",
      "distance_in_kms": "53.63899805156413\u{00A0}km",
      "id": "10681964632123375819",
      "latitude": 42.802288,
      "longitude": -70.8746643,
      "name": "Edit Style Lounge",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "191 Commercial St<br/>Provincetown, MA United States 2657",
      "distance_in_kms": "77.43733010983145\u{00A0}km",
      "id": "9297090700602507371",
      "latitude": 42.0485672,
      "longitude": -70.1890922,
      "name": "Century",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "191 Commercial Street\\n<br/>Provincetown, MA United States 02657",
      "distance_in_kms": "77.4394928722311\u{00A0}km",
      "id": "10681961241196363979",
      "latitude": 42.0485961,
      "longitude": -70.1890457,
      "name": "Century Shopper",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "191 Commercial Street\\n<br/>Provincetown, MA United States 02657",
      "distance_in_kms": "77.4394928722311\u{00A0}km",
      "id": "10681964627895517387",
      "latitude": 42.0485961,
      "longitude": -70.1890457,
      "name": "Century Shopper",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "107 Congress Street<br/>Portsmouth, NH United States 3801",
      "distance_in_kms": "85.48387816438931\u{00A0}km",
      "id": "9297101820977479787",
      "latitude": 43.076372,
      "longitude": -70.7598611,
      "name": "Janegee",
      "phone_number": "603 431 0335",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "10 Market Square<br/>Portsmouth, NH United States 3801",
      "distance_in_kms": "85.6333734019915\u{00A0}km",
      "id": "9297090663810072683",
      "latitude": 43.0772769,
      "longitude": -70.7574957,
      "name": "Sault New England",
      "phone_number": "(603) 766-9434",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://saultne.com/search?type=product,article,page&q=bellroy"
    },
    {
      "address": "301 U.S. 1 Route One<br/>Kittery, ME United States 3904",
      "distance_in_kms": "89.88324466343899\u{00A0}km",
      "id": "9297090648056266859",
      "latitude": 43.11237935,
      "longitude": -70.73525701,
      "name": "Kittery Trading Post",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "US-1<br/>Falmouth, ME United States 4105",
      "distance_in_kms": "167.842027695397\u{00A0}km",
      "id": "9297090645992669291",
      "latitude": 43.72469864,
      "longitude": -70.23279629,
      "name": "Tripquipment",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "61 Spring St<br/>Williamstown, MA United States 1267",
      "distance_in_kms": "182.39702951922814\u{00A0}km",
      "id": "9297090648744132715",
      "latitude": 42.71066663,
      "longitude": -73.20455902,
      "name": "Nature's Closet",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "95 Main St,<br/>Freeport, ME United States 4032",
      "distance_in_kms": "185.5982405701628\u{00A0}km",
      "id": "9297090701357482091",
      "latitude": 43.8577105,
      "longitude": -70.1029706,
      "name": "L.L Bean",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "Bow St<br/>Freeport, ME United States 4032",
      "distance_in_kms": "185.59878157816146\u{00A0}km",
      "id": "9297085054398234731",
      "latitude": 43.85743302,
      "longitude": -70.10212056,
      "name": "Toad&Co",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "1020 Chapel ST<br/>New Haven, CT United States",
      "distance_in_kms": "193.90555402161513\u{00A0}km",
      "id": "9297101718351249515",
      "latitude": 41.3072636,
      "longitude": -72.9293112,
      "name": "Raggs - New Haven",
      "phone_number": "(203) 865 3824",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://raggsnewhaven.com/collections/bellroy"
    },
    {
      "address": "705 Warren St<br/>Hudson, NY United States 12534",
      "distance_in_kms": "226.19604008061967\u{00A0}km",
      "id": "9297101813008302187",
      "latitude": 42.2469899,
      "longitude": -73.783544,
      "name": "Valley Variety",
      "phone_number": "518 828 0033",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "6423 Montgomery St #2, <br/>Rhinebeck, NY United States 12572",
      "distance_in_kms": "241.52660594284743\u{00A0}km",
      "id": "10681964636317679819",
      "latitude": 41.9279461,
      "longitude": -73.9128737,
      "name": "Paper Trail",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "32 John St<br/>Kingston, NY United States 12401",
      "distance_in_kms": "250.0162311582348\u{00A0}km",
      "id": "9297090675856113771",
      "latitude": 41.9338308,
      "longitude": -74.0189446,
      "name": "Hamilton and Adams",
      "phone_number": "(845) 383-1039",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://hamiltonandadams.com/search?q=bellroy&type=product"
    },
    {
      "address": "1000 Hurley Mountain Rd<br/>Kingston, NY United States",
      "distance_in_kms": "252.05440866263638\u{00A0}km",
      "id": "9297101745094131819",
      "latitude": 41.9533416,
      "longitude": -74.0490606,
      "name": "Kenco",
      "phone_number": "(845) 338 5021",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.atkenco.com/brand/bellroy-wallet-company"
    },
    {
      "address": "11 West 53 ST<br/>New York, NY United States",
      "distance_in_kms": "300.8218713061019\u{00A0}km",
      "id": "9297101755781218411",
      "latitude": 40.7614029,
      "longitude": -73.9776248,
      "name": "MOMA Design Store",
      "phone_number": "(212) 708 9700",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "6 Bedford Avenue<br/>Brooklyn, New York United States 11222",
      "distance_in_kms": "301.5411403684486\u{00A0}km",
      "id": "9297090679832313963",
      "latitude": 40.72397,
      "longitude": -73.9512769,
      "name": "ID New York",
      "phone_number": "7183872868",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "107 North 5th St<br/>Brooklyn, New York United States 11249",
      "distance_in_kms": "302.5465382799496\u{00A0}km",
      "id": "9297090679110893675",
      "latitude": 40.717663,
      "longitude": -73.9599187,
      "name": "ID New York",
      "phone_number": "(718) 387-2868",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "232B Bedford AVE<br/>Brooklyn, NY United States",
      "distance_in_kms": "302.5954522747346\u{00A0}km",
      "id": "9297101787037171819",
      "latitude": 40.7164514,
      "longitude": -73.9594296,
      "name": "ID New York",
      "phone_number": "(718) 599 0790",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "230 Grand (Ground Floor) ST<br/>Brooklyn, NY United States",
      "distance_in_kms": "302.80703715558036\u{00A0}km",
      "id": "9297101726135877739",
      "latitude": 40.7135869,
      "longitude": -73.9597006,
      "name": "Kai D",
      "phone_number": "(347) 765 2204",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.kaidutility.com/search?q=bellroy"
    },
    {
      "address": "500 W 33rd Street Suite 222B<br/>New York, NY United States 10001",
      "distance_in_kms": "302.83819201647464\u{00A0}km",
      "id": "9297084989671735403",
      "latitude": 40.75388,
      "longitude": -74.0000046,
      "name": "Rhone - Hudson Yards",
      "phone_number": "917-810-4770",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:54 UTC +00:00",
      "website": null
    },
    {
      "address": "133 5th Avenue<br/>New York, NY United States 10003",
      "distance_in_kms": "303.1694224928418\u{00A0}km",
      "id": "9297085001197682795",
      "latitude": 40.7393927,
      "longitude": -73.9907454,
      "name": "Rhone - Flatiron",
      "phone_number": "646-707-3515",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:54 UTC +00:00",
      "website": null
    },
    {
      "address": "867 Broadway<br/>New York, NY United States 10003",
      "distance_in_kms": "303.26768790682536\u{00A0}km",
      "id": "9297090703454634091",
      "latitude": 40.7377239,
      "longitude": -73.9905581,
      "name": "Paragon Sports (All Conditions Specialist)",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "49 Greenwich AVE<br/>New York, NY United States",
      "distance_in_kms": "304.0966449841121\u{00A0}km",
      "id": "9297101790946263147",
      "latitude": 40.7356119,
      "longitude": -74.0007335,
      "name": "Pertutti New York Inc.",
      "phone_number": "(212) 675 0113",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.pertutti.com/search?q=bellroy&type=product"
    },
    {
      "address": "52 Prince St<br/>New York, NY United States 10012",
      "distance_in_kms": "304.5796294863717\u{00A0}km",
      "id": "9297085040775135339",
      "latitude": 40.72359112,
      "longitude": -73.99603439,
      "name": "McNally Jackson Books",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "201 Mulberry St<br/>New York, NY United States 10012",
      "distance_in_kms": "304.74753972666156\u{00A0}km",
      "id": "9297085029853167723",
      "latitude": 40.72173097,
      "longitude": -73.99668092,
      "name": "ONS",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "81 Spring St<br/>New York, NY United States 10012",
      "distance_in_kms": "304.7660214343812\u{00A0}km",
      "id": "9297101734541262955",
      "latitude": 40.7228314,
      "longitude": -73.9980441,
      "name": "MOMA Design Store - Soho",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "121 7th Ave<br/>Brooklyn,, NY United States 11215",
      "distance_in_kms": "306.62442306395815\u{00A0}km",
      "id": "9297090677466726507",
      "latitude": 40.673338,
      "longitude": -73.975892,
      "name": "Fig",
      "phone_number": "(718) 622-5550",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://shopfigbrooklyn.com/search?q=bellroy"
    },
    {
      "address": "77 Atlantic Ave<br/>Brooklyn, NY United States 11201",
      "distance_in_kms": "306.8500284017242\u{00A0}km",
      "id": "9297101733870174315",
      "latitude": 40.691373,
      "longitude": -73.9976031,
      "name": "Hatchet Outdoor Supply Co - Brooklyn",
      "phone_number": "347 763 1963",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://hatchetsupply.com/collections/vendors?q=Bellroy"
    },
    {
      "address": "227 Court St<br/>Brooklyn, NY United States 11201",
      "distance_in_kms": "306.9496732163267\u{00A0}km",
      "id": "9297090675084361835",
      "latitude": 40.6861913,
      "longitude": -73.9938565,
      "name": "Haus Of Hanz",
      "phone_number": "(347) 457-5377",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://hausofhanz.com/search?q=bellroy"
    },
    {
      "address": "165 Maplewood AVE<br/>Maplewood, NJ United States 7040",
      "distance_in_kms": "323.4106112254703\u{00A0}km",
      "id": "9297101793378959467",
      "latitude": 40.7311225,
      "longitude": -74.2776959,
      "name": "No. 165",
      "phone_number": "(973) 275 1658",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "733 River Road<br/>Fair Haven, NJ United States 07704",
      "distance_in_kms": "332.671372734079\u{00A0}km",
      "id": "10681961248108576971",
      "latitude": 40.3642307,
      "longitude": -74.0366151,
      "name": "Canyon Pass Provisions",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "733 River Road<br/>Fair Haven, NJ United States 07704",
      "distance_in_kms": "332.671372734079\u{00A0}km",
      "id": "10681964642089042123",
      "latitude": 40.3642307,
      "longitude": -74.0366151,
      "name": "Canyon Pass Provisions",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "722 Cookman Ave\\n<br/>Asbury Park, NJ United States 07712",
      "distance_in_kms": "342.5054392152109\u{00A0}km",
      "id": "10681964634522517707",
      "latitude": 40.2156199,
      "longitude": -74.0127433,
      "name": "Interwoven",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "49 US 202\\nBuilding 1, Suite 2\\n<br/>Jersey City, NJ United States 07931",
      "distance_in_kms": "351.38579413251136\u{00A0}km",
      "id": "10681961246229528779",
      "latitude": 40.6851141,
      "longitude": -74.6347978,
      "name": "Hans Clothier",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "49 US 202\\nBuilding 1, Suite 2\\n<br/>Jersey City, NJ United States 07931",
      "distance_in_kms": "351.38579413251136\u{00A0}km",
      "id": "10681964640461652171",
      "latitude": 40.6851141,
      "longitude": -74.6347978,
      "name": "Hans Clothier",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "1455 Peel St<br/>Montreal, QC Canada H3A 1T5",
      "distance_in_kms": "406.12964643566755\u{00A0}km",
      "id": "9530906622960861324",
      "latitude": 45.5009341,
      "longitude": -73.5737683,
      "name": "Harry Rosen - Montreal Les Cours",
      "phone_number": "(514) 284-3315",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.harryrosen.com/en?gad_source=1&gclid=Cj0KCQiAoKeuBhCoARIsAB4WxteLAeEFO-04jwyjgEHqSS83FeP5TLwN24RsdAxiR47xIggjqCvE800aAqLCEALw_wcB"
    },
    {
      "address": "585 rue Ste-Catherine O<br/>Montreal, QC Canada H3B 3Y5",
      "distance_in_kms": "406.2531345287594\u{00A0}km",
      "id": "9526326426836402281",
      "latitude": 45.5041232,
      "longitude": -73.5692617,
      "name": "Hudson's Bay - 601 Montreal DTN , Montreal, QC",
      "phone_number": "(514) 281-4422",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.thebay.com"
    },
    {
      "address": "8989, Boulevard de l'Acadie<br/>Montreal, QC Canada H4N 3K1",
      "distance_in_kms": "412.2510385142518\u{00A0}km",
      "id": "9546629786491682820",
      "latitude": 45.532252,
      "longitude": -73.6514836,
      "name": "MEC Montreal",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.mec.ca/en/search?org_text=bellroy&text=bellroy"
    },
    {
      "address": "41 S 3rd St<br/>Philadelphia, PA United States 19106",
      "distance_in_kms": "434.52142296983476\u{00A0}km",
      "id": "9297090673524080747",
      "latitude": 39.9491116,
      "longitude": -75.1459422,
      "name": "Omoi Zakka Old City",
      "phone_number": "(215) 454-6910",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://omoionline.com/search?q=bellroy"
    },
    {
      "address": "1475, Boulevard Lebourgneuf<br/>Quebec City, QC Canada G2K 2G3",
      "distance_in_kms": "500.28875030614665\u{00A0}km",
      "id": "9546629776056254468",
      "latitude": 46.8341804,
      "longitude": -71.2989225,
      "name": "MEC Quebec",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.mec.ca/en/search?org_text=bellroy&text=bellroy"
    },
    {
      "address": "514 Washington ST Washington St Mall<br/>Cape May, NJ United States",
      "distance_in_kms": "500.4452869535291\u{00A0}km",
      "id": "9297101786248642667",
      "latitude": 38.9326183,
      "longitude": -74.9234004,
      "name": "Galvanic",
      "phone_number": "(609) 600 2608",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "366 Richmond Road<br/>Ottawa, ON Canada K2A 0E8",
      "distance_in_kms": "508.47367354459413\u{00A0}km",
      "id": "9546629776911892484",
      "latitude": 45.3912808,
      "longitude": -75.7548207,
      "name": "MEC Ottawa",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.mec.ca/en/search?org_text=bellroy&text=bellroy"
    },
    {
      "address": "2360 W. Joppa Road #110\\n<br/>Lutherville, MD United States 21093",
      "distance_in_kms": "573.9769463405253\u{00A0}km",
      "id": "10681964636837773515",
      "latitude": 39.4202232,
      "longitude": -76.6689638,
      "name": "Sassanova",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "28 Tank House Lane<br/>Toronto, ON Canada M5A 3C4",
      "distance_in_kms": "693.325207291381\u{00A0}km",
      "id": "9546629546292281348",
      "latitude": 43.6506177,
      "longitude": -79.3584082,
      "name": "Bergo Designs",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.bergodesigns.ca/collections/vendors?q=Bellroy"
    },
    {
      "address": "176 Yonge Street<br/>Toronto, ON Canada M5C 2L7",
      "distance_in_kms": "695.078763370353\u{00A0}km",
      "id": "9530906591822348428",
      "latitude": 43.6517906,
      "longitude": -79.3801688,
      "name": "Hudson's Bay - 1560 Queen St",
      "phone_number": "(416) 861-9111",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.thebay.com"
    },
    {
      "address": "218 Yonge St<br/>Toronto, ON Canada M5B 2H6",
      "distance_in_kms": "695.0943767208623\u{00A0}km",
      "id": "9530906624571474060",
      "latitude": 43.6534695,
      "longitude": -79.3799872,
      "name": "Harry Rosen - Eaton Centre",
      "phone_number": "(416) 598-8885",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.harryrosen.com/en?gad_source=1&gclid=Cj0KCQiAoKeuBhCoARIsAB4WxteLAeEFO-04jwyjgEHqSS83FeP5TLwN24RsdAxiR47xIggjqCvE800aAqLCEALw_wcB"
    },
    {
      "address": "220 Yonge St<br/>Toronto, ON Canada M5B 2H1",
      "distance_in_kms": "695.1140886063142\u{00A0}km",
      "id": "9535007841581006942",
      "latitude": 43.6539681,
      "longitude": -79.3801225,
      "name": "Blue Marine & Co.",
      "phone_number": "(416) 260-2355",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://bluemarine.ca"
    },
    {
      "address": "273 Front St<br/>Belleville, ON Canada K8N 2Z6",
      "distance_in_kms": "695.5087020161549\u{00A0}km",
      "id": "9530906627490709644",
      "latitude": 43.6442953,
      "longitude": -79.387245,
      "name": "Park Provisioners Barber Shop and Haberdashery",
      "phone_number": "(613) 962-2622",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://parkprovisioners.com"
    },
    {
      "address": "55 Bloor St W<br/>Toronto, ON Canada M4W 1A5",
      "distance_in_kms": "696.0260060283895\u{00A0}km",
      "id": "9530906628346347660",
      "latitude": 43.6691789,
      "longitude": -79.3881303,
      "name": "De Catarina",
      "phone_number": "(416) 966-0562",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://decatarina.com"
    },
    {
      "address": "55 Bloor St. W.<br/>Toronto, ON Canada M4W 1A5",
      "distance_in_kms": "696.0302554647865\u{00A0}km",
      "id": "9405356949639266445",
      "latitude": 43.6692201,
      "longitude": -79.3881743,
      "name": "Over the Rainbow",
      "phone_number": "416 - 967 - 7448",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "300 Queen Street West<br/>Toronto, ON Canada M5V 2A2",
      "distance_in_kms": "696.1385262137275\u{00A0}km",
      "id": "9546629791222857732",
      "latitude": 43.6496869,
      "longitude": -79.3939497,
      "name": "MEC Toronto",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.mec.ca/en/search?org_text=bellroy&text=bellroy"
    },
    {
      "address": "421 Queen St W<br/>Toronto, ON Canada M5V 2A5",
      "distance_in_kms": "696.2115793122562\u{00A0}km",
      "id": "9530906626618294412",
      "latitude": 43.6487774,
      "longitude": -79.3950704,
      "name": "Te Koop",
      "phone_number": "(416) 348-9485",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.te-koop.ca"
    },
    {
      "address": "784 Sheppard Avenue East<br/>North York, ON Canada M2K 1C3",
      "distance_in_kms": "696.9207743443158\u{00A0}km",
      "id": "9546629785787039748",
      "latitude": 43.7701813,
      "longitude": -79.375154,
      "name": "MEC North York",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.mec.ca/en/search?org_text=bellroy&text=bellroy"
    },
    {
      "address": "405 Roncesvalles Ave<br/>Toronto, ON Canada M6R 2N1",
      "distance_in_kms": "700.6774601067905\u{00A0}km",
      "id": "9546629775351611396",
      "latitude": 43.6510417,
      "longitude": -79.45064,
      "name": "Scout Ltd",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.iheartscout.com/collections/homegoods"
    },
    {
      "address": "1140 Queen Street E.<br/>Toronto, ON Canada M6R 2N1",
      "distance_in_kms": "700.6941142573487\u{00A0}km",
      "id": "9546629536058179588",
      "latitude": 43.651006,
      "longitude": -79.450857,
      "name": "Scout",
      "phone_number": "416 546 6922",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.iheartscout.com/search?type=products&q=bellroy*"
    },
    {
      "address": "5401 Dufferin St<br/>North York, ON Canada M6A 2T9",
      "distance_in_kms": "702.5350782384013\u{00A0}km",
      "id": "9530906621719347340",
      "latitude": 43.7248155,
      "longitude": -79.4570523,
      "name": "Hudson's Bay - 1554 Yorkdale",
      "phone_number": "(416) 789-8011",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.thebay.com"
    },
    {
      "address": "3092 Dundas St W<br/>Toronto, ON Canada M6P 1Z8",
      "distance_in_kms": "702.6985190592222\u{00A0}km",
      "id": "9530906625880096908",
      "latitude": 43.665644,
      "longitude": -79.472768,
      "name": "The Beau and Bauble",
      "phone_number": "(416) 904-6136",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.thebeauandbauble.com/home"
    },
    {
      "address": "100 City Centre Dr<br/>Mississauga, ON Canada L5B 2C9",
      "distance_in_kms": "715.0043367949885\u{00A0}km",
      "id": "9530906623598395532",
      "latitude": 43.5930011,
      "longitude": -79.6424732,
      "name": "Harry Rosen - Square One",
      "phone_number": "(905) 896-1103",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.harryrosen.com/en?gad_source=1&gclid=Cj0KCQiAoKeuBhCoARIsAB4WxteLAeEFO-04jwyjgEHqSS83FeP5TLwN24RsdAxiR47xIggjqCvE800aAqLCEALw_wcB"
    },
    {
      "address": "418 Poplar Hill Ct\\n<br/>Richmond, VA United States 23229",
      "distance_in_kms": "766.9400412004661\u{00A0}km",
      "id": "10681961242857308363",
      "latitude": 37.5838706,
      "longitude": -77.5648749,
      "name": "Cronies",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "418 Poplar Hill Ct\\n<br/>Richmond, VA United States 23229",
      "distance_in_kms": "766.9400412004661\u{00A0}km",
      "id": "10681964631016079563",
      "latitude": 37.5838706,
      "longitude": -77.5648749,
      "name": "Cronies",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "257 St Andrew ST<br/>Fergus, ON Canada N1M 1N8",
      "distance_in_kms": "775.613934445791\u{00A0}km",
      "id": "9571456088746754260",
      "latitude": 43.7041723,
      "longitude": -80.3794292,
      "name": "Broderick's Clothiers",
      "phone_number": "(519) 843 3870",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "http://www.brodericksclothiers.com"
    },
    {
      "address": "13 King N ST<br/>Waterloo, ON Canada N2J 2W6",
      "distance_in_kms": "783.8630584756495\u{00A0}km",
      "id": "9571456088042111188",
      "latitude": 43.4654568,
      "longitude": -80.5227581,
      "name": "Loop Clothing",
      "phone_number": "(519) 746 1688",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://bricksandbonds.ca/collections/bellroy"
    },
    {
      "address": "1043 Millmont St<br/>Charlottesville, VA United States 22903",
      "distance_in_kms": "793.2777223802545\u{00A0}km",
      "id": "9297090672819437675",
      "latitude": 38.0511496,
      "longitude": -78.5056013,
      "name": "Peace Frogs Travel Outfitters",
      "phone_number": "(434) 977-1415",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": null
    },
    {
      "address": "713 Richmond St<br/>London, Ontario Canada N6A 3H1",
      "distance_in_kms": "839.6546080806647\u{00A0}km",
      "id": "9546629779227148292",
      "latitude": 42.9940663,
      "longitude": -81.2526792,
      "name": "Endo Jewellers",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.endojewellers.com"
    },
    {
      "address": "118 Durham ST<br/>Sudbury, ON Canada P3E 3M7",
      "distance_in_kms": "916.266239808809\u{00A0}km",
      "id": "9571456085038989524",
      "latitude": 46.4907511,
      "longitude": -80.9947343,
      "name": "Reg Wilkinson Men's Fine Clothes",
      "phone_number": "(705) 675 6710",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://regwilkinson.ca/collections/bellroy"
    },
    {
      "address": "437 Front St<br/>Beaufort, NC United States 28516",
      "distance_in_kms": "976.9960238088031\u{00A0}km",
      "id": "10681961246816731339",
      "latitude": 34.7166295,
      "longitude": -76.664666,
      "name": "Harbor Specialties",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "437 Front St<br/>Beaufort, NC United States 28516",
      "distance_in_kms": "976.9960238088031\u{00A0}km",
      "id": "10681964640981745867",
      "latitude": 34.7166295,
      "longitude": -76.664666,
      "name": "Harbor Specialties",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "905 W. Main Street Suite 20G<br/>Durham, NC United States 27701",
      "distance_in_kms": "977.4200057104241\u{00A0}km",
      "id": "10681964633918537931",
      "latitude": 35.9995924,
      "longitude": -78.910257,
      "name": "INDIO",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    },
    {
      "address": "1435 Farmer St Suite 115<br/>Detroit, MI United States 48226",
      "distance_in_kms": "988.5470530964822\u{00A0}km",
      "id": "9297090676577534059",
      "latitude": 42.3347184,
      "longitude": -83.04813,
      "name": "Good Neighbor",
      "phone_number": "(313) 788-7800",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://shopgoodneighbor.com/search?q=bellroy"
    },
    {
      "address": "6 N Main Street<br/>Belmont, NC United States 28012",
      "distance_in_kms": "1170.6478276602008\u{00A0}km",
      "id": "10581525419297603786",
      "latitude": 35.2427953,
      "longitude": -81.0375846,
      "name": "Catawba River Outfitters",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-10-29 16:34 UTC +00:00",
      "website": null
    },
    {
      "address": "441 Vine St # 20<br/>Cincinnati, OH United States 45202",
      "distance_in_kms": "1191.9221457157926\u{00A0}km",
      "id": "9297090692918542443",
      "latitude": 39.100836,
      "longitude": -84.513238,
      "name": "Appointments",
      "phone_number": "513 421 7430",
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-05-07 02:53 UTC +00:00",
      "website": "https://www.411pens.com/portfolios-jotters?Collection=Bellroy"
    },
    {
      "address": "1894 Breton Road SE\\n<br/>Grand Rapids, MI United States 49506",
      "distance_in_kms": "1194.987508829315\u{00A0}km",
      "id": "10681961245726212299",
      "latitude": 42.9294879,
      "longitude": -85.6079617,
      "name": "Fitzgeralds Mens Store",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:28 UTC +00:00",
      "website": null
    },
    {
      "address": "1894 Breton Road SE\\n<br/>Grand Rapids, MI United States 49506",
      "distance_in_kms": "1194.987508829315\u{00A0}km",
      "id": "10681964633180340427",
      "latitude": 42.9294879,
      "longitude": -85.6079617,
      "name": "Fitzgeralds Mens Store",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2025-01-06 23:32 UTC +00:00",
      "website": null
    }
  ]
}
"""
