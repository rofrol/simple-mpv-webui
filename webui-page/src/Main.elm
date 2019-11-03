module Main exposing (..)

import Browser
import Browser.Dom
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FontAwesome.Icon as Icon exposing (Icon)
import FontAwesome.Solid as Icon
import Html.Attributes
import Html.Events
import Http
import Json.Decode as D exposing (Decoder)
import Task


type alias Model =
    { position : Int
    , maybePositionElement : Maybe Browser.Dom.Element
    , status : Status
    }


type Msg
    = Sent (Result Http.Error D.Value)
    | TogglePause
    | SeekBack
    | SeekForward
    | PlaylistPrev
    | PlaylistNext
    | ClickMsg Coords
    | GetPositionElement (Result Browser.Dom.Error Browser.Dom.Element)
    | GotStatus (Result Http.Error Status)


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init _ =
    ( initialModel
    , Cmd.batch
        [ Task.attempt GetPositionElement (Browser.Dom.getElement "position")
        , getStatus
        ]
    )


initialModel : Model
initialModel =
    { position = 0
    , maybePositionElement = Nothing
    , status = { duration = 0, position = 0, pause = True }
    }


view model =
    { title = "Title"
    , body =
        [ Element.layoutWith { options = [ focusStyle focusStyle_ ] }
            [ padding 40 ]
            (column [ width fill, spacing 20 ]
                [ slider "position" ClickMsg model.maybePositionElement model.position
                , button (Just TogglePause)
                    (Icon.viewIcon
                        (if model.status.pause then
                            Icon.play

                         else
                            Icon.pause
                        )
                        |> Element.html
                    )
                , row [ spacing 20, width fill ]
                    [ button (Just SeekBack)
                        (Icon.viewIcon Icon.backward |> Element.html)
                    , button (Just SeekForward)
                        (Icon.viewIcon Icon.forward |> Element.html)
                    ]
                , row [ spacing 20, width fill ]
                    [ button (Just PlaylistPrev)
                        (Icon.viewIcon Icon.fastBackward |> Element.html)
                    , button (Just PlaylistNext)
                        (Icon.viewIcon Icon.fastForward |> Element.html)
                    ]
                ]
            )
        ]
    }


focusStyle_ : FocusStyle
focusStyle_ =
    { borderColor = Nothing
    , backgroundColor = Nothing
    , shadow = Nothing
    }


style =
    { borderWidth = 3
    , borderRounded = 6
    , borderColor = rgb255 0 0 0
    , buttonHeight = px 160
    }


button onPress element =
    Input.button
        [ Border.color style.borderColor
        , Border.width style.borderWidth
        , Border.rounded style.borderRounded
        , padding 10
        , width fill
        , height style.buttonHeight
        , Font.size 60
        ]
        { onPress = onPress
        , label = el [ centerX, width (px 80), height (px 80) ] element
        }


slider : String -> (Coords -> Msg) -> Maybe Browser.Dom.Element -> Int -> Element Msg
slider id msg maybePositionElement position =
    let
        value : Int
        value =
            case maybePositionElement of
                Just element ->
                    round <| toFloat position / 100 * element.element.width

                Nothing ->
                    0
    in
    el
        [ width fill
        , height style.buttonHeight
        , Border.color style.borderColor
        , Border.width style.borderWidth
        , Border.rounded style.borderRounded
        ]
        (el [ width fill, height fill, Html.Attributes.id id |> Element.htmlAttribute ]
            (el
                [ onClickCoords msg
                , width fill
                , height fill
                ]
                (el
                    [ width (px value)
                    , height fill
                    , Background.color style.borderColor
                    ]
                    Element.none
                )
            )
        )


onClickCoords : (Coords -> msg) -> Attribute msg
onClickCoords msg =
    Html.Events.on "click" (D.map msg localCoords) |> Element.htmlAttribute


type alias Coords =
    { x : Int
    , y : Int
    }


localCoords : Decoder Coords
localCoords =
    D.map2 Coords
        (D.field "offsetX" D.int)
        (D.field "offsetY" D.int)


update msg model =
    case Debug.log "msg" msg of
        Sent _ ->
            ( model, Cmd.none )

        TogglePause ->
            let
                status =
                    model.status

                newStatus =
                    { status | pause = not status.pause }
            in
            ( { model | status = newStatus }, send "toggle_pause" )

        SeekBack ->
            ( model, send "seek/-10" )

        SeekForward ->
            ( model, send "seek/10" )

        PlaylistPrev ->
            ( model, send "playlist_prev" )

        PlaylistNext ->
            ( model, send "playlist_next" )

        ClickMsg coords ->
            let
                position =
                    case model.maybePositionElement of
                        Just element ->
                            round <| 100 * toFloat coords.x / element.element.width

                        Nothing ->
                            0
            in
            ( { model | position = position }, send ("set_position/" ++ String.fromFloat ((toFloat position / 100) * toFloat model.status.duration)) )

        GetPositionElement result ->
            ( { model | maybePositionElement = Result.toMaybe result }, Cmd.none )

        GotStatus (Ok status) ->
            ( { model | position = round (100 * toFloat status.position / toFloat status.duration), status = status }, Cmd.none )

        GotStatus (Err err) ->
            ( model, Cmd.none )


send command =
    Http.post
        { url = "http://192.168.0.10:8080/api/" ++ command
        , body = Http.emptyBody
        , expect = Http.expectJson Sent D.value
        }


getStatus =
    Http.get
        { url = "http://192.168.0.10:8080/api/status"
        , expect = Http.expectJson GotStatus statusDecoder
        }


type alias Status =
    { duration : Int
    , position : Int
    , pause : Bool
    }


statusDecoder =
    D.map3 Status
        (D.field "duration" D.int)
        (D.field "position" D.int)
        (D.field "pause" D.bool)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
