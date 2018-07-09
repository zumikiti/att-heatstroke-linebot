desc "This task is called by the Heroku scheduler add-on"
task :update_hour => :environment do
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require "json"

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  API_KEY = ENV["OPENWEATHER_API_KEY"]
  BASE_URL = "http://api.openweathermap.org/data/2.5/weather"

  # urlを指定して、jsonをシンボル化して格納
  url = open( "#{BASE_URL}?q=Tokyo,jp&APPID=#{API_KEY}" )
  res = JSON.parse( url.read , {symbolize_names: true} )

  # 最高気温（main > temp_max）を取得
  temp_max = res[:main][:temp_max].to_i - 273.15
  #puts "気温： #{temp_max - 273.15}度"
  humidity = res[:main][:humidity].to_i
  #puts "湿度： #{humidity}%"

  # temp_maxまたはhumidityがnilでなければ
  if temp_max > 33 || humidity > 80
    if temp_max > 33 && humidity > 80
      word1 = "今、気温も湿度も高いね。"
    elsif temp_max > 33
      word1 = "今、とても気温が高いね"
    elsif humidity > 80
      word1 = "今、気温はそこそこだけど、湿度が高いくてむす無視するね"
    end

    push =
      "#{word1}\n気温： #{temp_max - 273.15}度\n湿度： #{humidity}%\nこまめに水分補給して、熱中症にならないように気をつけてね（＞＜）"

    # メッセージの発信先idを配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
    user_ids = User.all.pluck(:line_id)
    message = {
      type: 'text',
      text: push
    }
    response = client.multicast(user_ids, message)
  end
  "OK"
end
