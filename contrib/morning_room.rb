#!/usr/bin/ruby
# Client to help you in the morning.
#
# Displays departure time from one or two stops and outside temperature.

require 'optparse'
require_relative '../client/lib'

require 'xmlsimple'
require 'forecast_io'
require_relative '../client/lib/weather_cache'
require 'chronic'

ForecastIO.configure do |configuration|
    configuration.api_key = 'd11940efdf0245dea23a362fa4a25b7f'
end

font = muni_sign_font(File.join(File.dirname(__FILE__), '..', 'client', 'font'))

StationTime = Struct.new(:train, :time)

options = {
  :bad_timing => 13,
  :update_interval => 15,
  :weather_hour => 19,
}
OptionParser.new do |opts|
  opts.banner = "Usage: morning_room.rb --route F --direction inbound --stop 'Ferry Building'"

  opts.on('--route [ROUTE]', "Route to get predictions for") {|v| options[:route] = v}
  opts.on('--direction [inbound/outbound]', "Route direction") {|v| options[:direction] = v}
  opts.on('--stop [STOP_NAME]', "Stop to watch") {|v| options[:stop] = v}
  opts.on('--timing MINUTES', Integer, "Warn if distance is longer than this.") {|v| options[:bad_timing] = v}
  opts.on('--update-interval SECONDS', Integer, "Update sign each number of seconds") {|v| options[:update_interval] = v}

  # Backup route
  opts.on('--backup-route [ROUTE]', "Route to get predictions for on 2nd line (3 predictions only)") {|v| options[:route2] = v}
  opts.on('--backup-direction [inbound/outbound]', "2nd line route direction") {|v| options[:direction2] = v}
  opts.on('--backup-stop [STOP_NAME]', "2nd line stop to watch") {|v| options[:stop2] = v}

  #Weather
  opts.on('--weather-url [URL]', "The url from weather.gov to fetch a weather from.  Click on Tabular Weather, and choose XML.") {|v| options[:weather_xml] = v}
  opts.on('--weather-hour [HOUR]', "Hour of the day (0..23) to get the weather of") {|v| options[:weather_hour] = v}

  # Darkening
  opts.on('--dark-file [FILENAME]', "Turn off the sign instead of updating, if FILENAME exists") {|v| options[:dark_file] = v}
end.parse!

# Returns array of predictions for this route, direction, and stop in UTC times.
# in_out is 'inbound' for inbound routes, or 'outbound'
def get_arrival_times(route, stop, in_out)
  raise unless route and stop and in_out
  route_handler = Muni::Route.find(route)
  stop_handler = route_handler.send(in_out.to_sym).stop_at(stop)
  raise "Couldn't find stop: found '#{stop_handler.title}' for '#{stop}'" if
      stop != stop_handler.title
  # return stop_handler.predictions.map(&:time)
  # stop_handler.predictions.map(&:time).map {|t| StationTime.new(route, t) }
  stop_handler.predictions.map(&:time).map {|t| StationTime.new(route, t) }.select { |st| (st.time - Time.now) > 60 }
end

def get_underground_church
  l_inbound = get_arrival_times("L", "Church St Station Inbound", "inbound")
  m_inbound = get_arrival_times("M", "Church St Station Inbound", "inbound")
  kt_inbound = get_arrival_times("KT", "Church St Station Inbound", "inbound")
  # t_inbound = get_arrival_times("T", "Church St Station Inbound", "inbound")

  (l_inbound + m_inbound + kt_inbound).sort{|x,y| x[:time] <=> y[:time] }
end

def get_j
  # get_arrival_times("J", "Church St & Duboce Ave", "inbound")
  get_arrival_times("J", "Church St & Market St", "inbound")
end

def update_sign_default(font, options)
  update_sign(font, {:route2 => true, :bad_timing=>13, :update_interval=>15, :weather_hour=>"20", :route=>"30", :direction=>"outbound", :stop=>"Townsend & 4th", :weather_xml=>"http://forecast.weather.gov/MapClick.php?lat=37.767556&lon=-122.427979&FcstType=digitalDWML"})
end

def update_sign(font, options)
  # Render these times
  def prediction_string(arrival_times, options)
    puts arrival_times.inspect
    # predictions = arrival_times.map{|t| ((t - Time.now)/60).floor}

    predictions_str = ''
    prev = 0
    first = true
    puts "xx"

    if arrival_times.first.respond_to?(:train)
      arrival_times.each {|at| at.time = ((at.time - Time.now)/60).floor }

      puts "x"
      puts arrival_times.inspect
      arrival_times.each do |at|
        if !first
          predictions_str << "#{((at.time-prev) >= options[:bad_timing])? 128.chr : '-'}"
        end
        first = false
        predictions_str << (at.train == "KT" ? "#{at.time}#{131.chr}" : "#{at.time}")
        # predictions_str << "#{at.time}#{at.train}"
        prev = at.time

      end
    else
      predictions = arrival_times.map{|t| ((t - Time.now)/60).floor}

      predictions.each do |t|
        if !first
          predictions_str << "#{((t-prev) >= options[:bad_timing])? 128.chr : '-'}"
        end
        first = false
        predictions_str << "#{t}"
        prev = t
      end
    end

    # for t in predictions do
    #   # Add ellipsis between predictions if distance's too long.
    #   # 31 is a specific charater defined in specific.simpleglyphs
    #   if not first
    #     predictions_str << "#{((t-prev) >= options[:bad_timing])? 128.chr : '-'}"
    #   end
    #   first = false
    #   predictions_str << "#{t}"
    #   prev = t
    # end

    return predictions_str
  end

  arrival_times = get_underground_church.first(6)
  # line1 = "#{options[:route]}:#{prediction_string(arrival_times, options)}"
  line1 = prediction_string(arrival_times, options)
  puts "XXX"
  puts line1.inspect

  if options[:route2]
    # arrival_times = get_arrival_times(options[:route2], options[:stop2], options[:direction2])
    # arrival_times = arrival_times.slice(0, 3)
    # line2 = "#{options[:route2]}:#{prediction_string(arrival_times, options)}"
    arrival_times = get_j
    arrival_times = arrival_times.first(3)
    line2 = "J:#{prediction_string(arrival_times, options)}"
  else
    line2 = ""
  end

  # Get weather.
  if options[:weather_xml]; begin
    # Load forecast.  TODO: add throttling (it hardly changes every 30 seconds).
    # url = options[:weather_xml]
    # xml = Net::HTTP.get(URI.parse(url))
    # doc =  XmlSimple.xml_in(xml)
    # # Pad hour with zero.
    # hour = sprintf("%2d", options[:weather_hour])
    # # Find table cell index that represents the hour we're interested in.
    # time_index = doc['data'].first['time-layout'].first['start-valid-time'].find_index {|t| t =~ /T#{hour}/ }
    # # Now find the actual temperature at that hour.
    # weather_later = doc['data'].first['parameters'].first['temperature'].first['value'][time_index]
    # # And the current temperature, too (it's in the first cell).
    # weather_now = doc['data'].first['parameters'].first['temperature'].first['value'][0]

    # # Get rain conditions
    # begin
    #   conditions = doc['data'].first['parameters'].first['weather'].first['weather-conditions'][time_index]
    #   rain = (conditions['value'] || []).find {|c| c['weather-type'] == 'rain'}
    #   if rain
    #     coverage_map = {
    #       # Todo: uncover more rainfall phrases!
    #       'slight chance' => 141.chr,
    #       'chance' => 143.chr,
    #       'likely' => 146.chr,
    #     }
    #     # Display "?" if the rainfall string is not recognized (otherwise I'd
    #     # not see that there's a chance of rain in such cases).
    #     rain_str = coverage_map[rain['coverage'] || "?"]
    #   end
    # rescue => e
    #   $stderr.puts "Weather error received: #{e}\n#{e.backtrace.join("\n")}"
    #   rain_str = ''
    # end

    # forecast = ForecastIO.forecast(37.767556, -122.427979)

    # low_temp = forecast["daily"]["data"].first["temperatureMin"].to_i
    # high_temp = forecast["daily"]["data"].first["temperatureMax"].to_i

    low_temp, high_temp = WeatherCache.new.retrieve_weather
    # weather_str = "#{130.chr}#{weather_now}#{129.chr}#{130.chr}#{weather_later}#{rain_str}"
    weather_str = "#{130.chr}#{low_temp}#{129.chr}#{130.chr}#{high_temp}"
  rescue => e
    # We rescue on various key errors, and inavailability.  Turn this on for
    # debugging.
    # $stderr.puts "Weather error received: #{e}\n#{e.backtrace.join("\n")}"
    weather_str = 'E'
  end; end

  line2 << " #{weather_str}"

  LED_Sign.pic(font.render_multiline([line1, line2], 8, :ignore_shift_h => true, :distance => 0, :fixed_width => LED_Sign::SCREEN_WIDTH).zero_one)
end

def display_forecast(font)
  line1, line2 = '', ''
  low_temp, high_temp = WeatherCache.new.retrieve_weather
  weather_str = "#{130.chr}#{low_temp}#{129.chr}#{130.chr}#{high_temp}"
  line1 << weather_str
  forecast = WeatherCache.new.retrieve_forecast

  forecast_str = "#{130.chr}#{forecast[0]} #{130.chr}#{forecast[1]} #{130.chr}#{forecast[2]}"
  puts forecast_str
  line2 << forecast_str
  LED_Sign.pic(font.render_multiline([line1, line2], 8, :ignore_shift_h => true, :distance => 0, :fixed_width => LED_Sign::SCREEN_WIDTH).zero_one)
end

@update_interval = options[:update_interval]
@override = File.exists?("./override.txt")

while true
  begin
    if Time.now < Chronic.parse("today at 3pm") || @override
      @update_interval = options[:update_interval]
      puts "update_interval #{@update_interval}"
      puts "before"
      darken_if_necessary(options) or update_sign_default(font, options)
    else
      @update_interval = 1800
      puts "after"
      puts "update_interval #{@update_interval}"
      display_forecast(font)
    end
  rescue => e
    $stderr.puts "Well, we continue despite this error: #{e}\n#{e.backtrace.join("\n")}"
  end
  sleep(@update_interval)
end

