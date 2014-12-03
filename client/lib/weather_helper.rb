require 'yaml'
require 'chronic'
require 'forecast_io'
require 'yaml/store'

API_KEY = YAML.load_file(File.join(File.dirname(__FILE__), "../../.forecastio.yml"))["api_key"]
LATITUDE, LONGITUDE = 37.767556, -122.427979

ForecastIO.configure do |configuration|
    configuration.api_key = API_KEY
end

class WeatherHelper
  attr_reader :latitude, :longitude, :last_updated, :cache_window, :weather_store, :cache, :todays_temp, :forecast

  def initialize(cache=true, latitude=LATITUDE, longitude=LONGITUDE) # defaults to SF
    @latitude = latitude
    @longitude = longitude
    @weather_store = YAML::Store.new("cached_weather.yml")
    @cache_window = 1800 # in seconds
    @cache = cache
  end

  def todays_weather
    retrieve_cache
    get_weather unless within_cache_window?
    [todays_temp[:low], todays_temp[:high]]
  end

  def this_weeks_forecast
    retrieve_cache
    get_weather unless within_cache_window?
    forecast
  end

  private

  def retrieve_cache
    @last_updated = weather_store.transaction { weather_store.fetch(:time, nil) }
    @todays_temp  = weather_store.transaction { weather_store.fetch(:todays_temp, {}) }
    @forecast     = weather_store.transaction { weather_store.fetch(:forecast, []) }
  end

  def within_cache_window?
    return false if @last_updated.nil?
    puts (Time.now - @last_updated)
    (Time.now - @last_updated) < @cache_window
  end

  def get_weather
    raw_forecast        = ForecastIO.forecast(latitude, longitude)
    @todays_temp[:low]  = raw_forecast["daily"]["data"].first["temperatureMin"].to_i
    @todays_temp[:high] = raw_forecast["daily"]["data"].first["temperatureMax"].to_i
    @forecast           = raw_forecast["daily"]["data"].first(3).map{|t| t.temperatureMax.to_i }

    cache_weather if cache
  end

  def cache_weather
    weather_store.transaction do
      weather_store[:time] = Time.now
      weather_store[:todays_temp] = { low: todays_temp[:low],
                                      high: todays_temp[:high] }
      weather_store[:forecast] = forecast
    end
  end
end
