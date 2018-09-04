desc "This task is called by the Heroku scheduler add-on"
task :update_hour => :environment do
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require "json"
  require "date"

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  API_KEY = ENV["OPENWEATHER_API_KEY"]
  BASE_URL = "http://api.openweathermap.org/data/2.5/weather"

  # 定期実行を日本時間；9時〜19時に限定。UTC；0時〜10時
  time = DateTime.now
  hour = time.hour
  if hour >= 0 && hour <= 10
    # urlを指定して、jsonをシンボル化して格納
    url = open( "#{BASE_URL}?q=Tokyo,jp&APPID=#{API_KEY}" )
    res = JSON.parse( url.read , {symbolize_names: true} )

    # 最高気温（main > temp_max）を取得
    temp_max = res[:main][:temp_max].to_i - 273
    humidity = res[:main][:humidity].to_i
    # logデバック用
    puts "気温： #{temp_max}度, 湿度： #{humidity}%"

    # 気温（temp_max）が30度以上、または湿度（humidity）が80％以上の場合実行
    if temp_max >= 30 || humidity >= 80
      # 気温（temp_max）が25度以上の場合のみ実行
      if temp_max => 25

        weather_id = res[:weather][0][:id].to_i
        puts "weather_id: #{weather_id}"
        if weather_id == 800
          weather = "晴天"
        elsif weather_id == 801
          weather = "晴れ"
        elsif weather_id > 801
          weather = "曇り"
        elsif weather_id >= 200 && weather_id < 300
          weather = "雷雨"
        elsif weather_id >= 300 && weather_id < 400
          weather = "霧雨"
        elsif weather_id == 500 || weather_id == 501
          weather = "雨"
        elsif weather_id >= 502 && weather_id < 600
          weather = "大雨"
        elsif weather_id >= 600 && weather_id < 700
          weather = "雪"
        elsif weather_id >= 700 && weather_id < 800
          weather = "霧"
        end
        puts "weather: #{weather}"

        if temp_max >= 30 && humidity >= 80
          word1 = "今、気温も湿度も高いね。"
        elsif temp_max >= 33
          word1 = "今、とても気温が高いね"
        elsif temp_max >= 30
          word1 = "今、気温が高いね"
        elsif humidity >= 80
          word1 = "今、気温はそこそこだけど、湿度が高くてムシムシするね"
        end

        # weatherによって対策をメッセージに載せる。
        if weather_id == 800 || weather_id == 801
          word2 = "日差しが強いので、日陰に移動して直射日光を避け、コンクリートやアスファルトの上は避けましょう。\n熱中症にならないように気をつけてね（＞＜）"
        elsif weather_id > 801
          word2 = "日差しが弱くても、熱中症にはなるからね！\n湿度が高いなら屋内だと、除湿機を使ってみましょう。\n外で風が弱ければ、扇子などで風を起こして体温の上昇を防ぎましょう。"
        else
          word2 = "こまめに水分補給して、熱中症にならないように気をつけてね（＞＜）"
        end

        push =
          "現在の天気は#{weather}だよ。\n#{word1}\n気温： #{temp_max}度\n湿度： #{humidity}%\n#{word2}"

        # メッセージの発信先idを配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
        user_ids = User.all.pluck(:line_id)
        message = {
          type: 'text',
          text: push
        }
        response = client.multicast(user_ids, message)
      end
    end
  else
    puts "今は定期実行対象外の時間帯です。"
  end
  "OK"
end
