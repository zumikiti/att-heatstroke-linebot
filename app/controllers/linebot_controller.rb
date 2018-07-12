class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]
  def callback
    API_KEY = ENV["OPENWEATHER_API_KEY"]
    BASE_URL = "http://api.openweathermap.org/data/2.5/weather"
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each { |event|
    case event
      # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
          when Line::Bot::Event::MessageType::Text
            # event.message['text']：ユーザーから送られたメッセージ
            input = event.message['text']
            url  = "https://www.drk7.jp/weather/xml/13.xml"
            xml  = open( url ).read.toutf8
            doc = REXML::Document.new(xml)
            xpath = 'weatherforecast/pref/area[4]/'

            puts "MSG受け取った。"

            case input
            # 「今日」or「きょう」というメッセージが含まれる場合
            when /.*(今日|きょう).*/
              weather = doc.elements[xpath + 'info[1]/weather'].text
              celsius_max = doc.elements[xpath + 'info[1]/temperature/range[1]'].text
              celsius_min = doc.elements[xpath + 'info[1]/temperature/range[2]'].text
              if weather || celsius_max || celsius_min
                push ="今日の天気だよ。\n#{fix_word}"
              end
            # 「明日」or「あした」というワードが含まれる場合
            when /.*(明日|あした).*/
              # info[2]：明日の天気
              weather = doc.elements[xpath + 'info[2]/weather'].text
              celsius_max = doc.elements[xpath + 'info[2]/temperature/range[1]'].text
              celsius_min = doc.elements[xpath + 'info[2]/temperature/range[2]'].text
              if weather || celsius_max || celsius_min
                fix_word = "天気：#{weather}\n最高気温：#{celsius_max}度\n最低気温：#{celsius_min}度"
                push ="明日の天気だよ。\n#{fix_word}"
              end
            when /.*(明後日|あさって).*/
              weather = doc.elements[xpath + 'info[3]/weather'].text
              celsius_max = doc.elements[xpath + 'info[3]/temperature/range[1]'].text
              celsius_min = doc.elements[xpath + 'info[3]/temperature/range[2]'].text
              if weather || celsius_max || celsius_min
                fix_word = "天気：#{weather}\n最高気温：#{celsius_max}度\n最低気温：#{celsius_min}度"
                push ="明後日の天気だよ。\n#{fix_word}"
              end
            when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
              push =
                "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
            when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
              push =
                "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
            else
              # 現在の天気、気温、湿度を返す。
              url = open( "#{BASE_URL}?q=Tokyo,jp&APPID=#{API_KEY}" )
              res = JSON.parse( url.read , {symbolize_names: true} )
              weather_icon = res[:weather][0][:icon].to_s
              temp_max = res[:main][:temp_max].to_i - 273
              humidity = res[:main][:humidity].to_i

              # weather_iconを文字に変換
              # 参考：https://www.sglabs.jp/openweathermap-api/
              puts "weather_icon: #{weather_icon}"
              weather = weather_has[weather_icon]
              puts "weather: #{weather_has}"

              # temp_maxまたはhumidityがnilでなければ
              if temp_max >= 30 || humidity >= 80
                if temp_max >= 30 && humidity >= 80
                  word1 = "今、気温も湿度も高いね。"
                elsif temp_max >= 33
                  word1 = "今、とても気温が高いね"
                elsif temp_max >= 30
                  word1 = "今、気温が高いね"
                elsif humidity >= 80
                  word1 = "今、気温はそこそこだけど、湿度が高くてムシムシするね"
                end
                word2 = "こまめに水分補給して、熱中症にならないように気をつけてね（＞＜）"
              else
                word1 = "気温も湿度も落ち着いてるけど、注意してね。"
                word2 = "今日があなたにとっていい日になりますように（^^）"
              end

              puts "天気：#{weather}, 気温：#{temp_max}, 湿度：#{humidity}"

              push = "現在の天気は#{weather}だよ。\n#{word1}\n気温： #{temp_max}度\n湿度： #{humidity}%\n#{word2}"
            end
          # テキスト以外（画像等）のメッセージが送られた場合
          else
            push = "テキスト以外はわからないよ〜(；；)"
          end
          message = {
            type: 'text',
            text: push
          }
          client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
        when Line::Bot::Event::Follow
          # 登録したユーザーのidをユーザーテーブルに格納
          line_id = event['source']['userId']
          User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
        when Line::Bot::Event::Unfollow
          # お友達解除したユーザーのデータをユーザーテーブルから削除
          line_id = event['source']['userId']
          User.find_by(line_id: line_id).destroy
        end
      }
      head :ok
    end

    private

    def client
      @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
      }
    end

end
