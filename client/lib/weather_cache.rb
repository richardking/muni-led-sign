require 'yaml'
require 'chronic'
require 'forecast_io'

ForecastIO.configure do |configuration|
    configuration.api_key = 'd11940efdf0245dea23a362fa4a25b7f'
end

class WeatherCache
  attr_reader :time, :low_temp, :high_temp, :timing, :weather

  def initialize
    if File.exist?('cached_weather.yml')
      @weather = YAML.load_file('cached_weather.yml')
      @time = @weather["time"]
      @low_temp = @weather["temp"]["low"]
      @high_temp = @weather["temp"]["high"]
    else
      @weather = {}
      @time = nil
    end
    # if File.exist?('cached_forecast.yml')
    #   @forecast = YAML.load_file('cached_forecast.yml')
    #   @time = @forecast["time"]
    #   @forecaset = @weather["forecast"]
    # else
    #   @forecast = {}
    #   @time = nil
    # end
    @timing = 1800 #seconds, half hour
  end

  def within_time?
    return false if @time.nil?
    puts (Time.now - @time)
    (Time.now - @time) < @timing
  end

  def cache_weather(lo, hi)
    weather["time"] = Time.now
    weather["temp"] = { "low" => lo, "high" => hi }

    File.open('cached_weather.yml', 'w') { |f| f.write weather.to_yaml }
  end

  def cache_forecast(forecast)
    weather["time"] = Time.now
    weather["forecast"] = forecast

    File.open('cached_forecast.yml', 'w') { |f| f.write weather.to_yaml }
  end

  def get_weather
    puts "get weather"
    forecast = ForecastIO.forecast(37.767556, -122.427979)

    @time = Time.now
    @low_temp = forecast["daily"]["data"].first["temperatureMin"].to_i
    @high_temp = forecast["daily"]["data"].first["temperatureMax"].to_i

    cache_weather(@low_temp, @high_temp)

    [low_temp, high_temp]
  end

  def get_forecast
    puts "get forecast"
    forecast = ForecastIO.forecast(37.767556, -122.427979)

    @time = Time.now
    @forecast = forecast["daily"]["data"].first(3).map{|t| t.temperatureMax.to_i }

    # cache_forecast(@forecast)

    puts @forecast.inspect
    @forecast
  end

  def retrieve_forecast
    get_forecast
    # if within_time?
    #   [@low_temp, @high_temp]
    # else
    #   get_weather
    # end
  end

  def retrieve_weather
    if within_time?
      [@low_temp, @high_temp]
    else
      get_weather
    end
  end
end
