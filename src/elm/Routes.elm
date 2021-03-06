{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Routes exposing (Route(..), href, match, routeToUrl)

import Api.Pagination as Pagination
import Html
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Builder as UB
import Url.Parser exposing ((</>), (<?>), Parser, fragment, map, oneOf, parse, s, string, top)
import Url.Parser.Query as Query
import Vela exposing (AuthParams, BuildNumber, Event, FocusFragment, Org, Repo)



-- TYPES


type Route
    = Overview
    | AddRepositories
    | Hooks Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | RepoSettings Org Repo
    | RepositoryBuilds Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event)
    | Build Org Repo BuildNumber FocusFragment
    | Settings
    | Login
    | Logout
    | Authenticate AuthParams
    | NotFound



-- ROUTES


routes : Parser (Route -> a) a
routes =
    oneOf
        [ map Overview top
        , map AddRepositories (s "account" </> s "add-repos")
        , map Login (s "account" </> s "login")
        , map Logout (s "account" </> s "logout")
        , map Settings (s "account" </> s "settings")
        , parseAuth
        , map Hooks (string </> string </> s "hooks" <?> Query.int "page" <?> Query.int "per_page")
        , map RepoSettings (string </> string </> s "settings")
        , map RepositoryBuilds (string </> string <?> Query.int "page" <?> Query.int "per_page" <?> Query.string "event")
        , map Build (string </> string </> string </> fragment identity)
        , map NotFound (s "404")
        ]


match : Url -> Route
match url =
    parse routes url |> Maybe.withDefault NotFound


parseAuth : Parser (Route -> a) a
parseAuth =
    map
        (\code state ->
            Authenticate { code = code, state = state }
        )
        (s "account"
            </> s "authenticate"
            <?> Query.string "code"
            <?> Query.string "state"
        )



-- HELPER


routeToUrl : Route -> String
routeToUrl route =
    case route of
        Overview ->
            "/"

        AddRepositories ->
            "/account/add-repos"

        RepoSettings org repo ->
            "/" ++ org ++ "/" ++ repo ++ "/settings"

        RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            "/" ++ org ++ "/" ++ repo ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage ++ eventToQueryParam maybeEvent)

        Hooks org repo maybePage maybePerPage ->
            "/" ++ org ++ "/" ++ repo ++ "/hooks" ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage)

        Build org repo buildNumber logFocus ->
            "/" ++ org ++ "/" ++ repo ++ "/" ++ buildNumber ++ Maybe.withDefault "" logFocus

        Authenticate { code, state } ->
            "/account/authenticate" ++ paramsToQueryString { code = code, state = state }

        Settings ->
            "/account/settings"

        Login ->
            "/account/login"

        Logout ->
            "/account/logout"

        NotFound ->
            "/404"


paramsToQueryString : AuthParams -> String
paramsToQueryString params =
    case ( params.code, params.state ) of
        ( Nothing, Nothing ) ->
            ""

        ( Just code, Just state ) ->
            "?code=" ++ code ++ "&state=" ++ state

        ( Just code, Nothing ) ->
            "?code" ++ code

        _ ->
            ""


eventToQueryParam : Maybe Event -> List UB.QueryParameter
eventToQueryParam maybeEvent =
    if maybeEvent /= Nothing then
        [ UB.string "event" <| Maybe.withDefault "" maybeEvent ]

    else
        []


href : Route -> Html.Attribute msg
href route =
    Attr.href (routeToUrl route)
