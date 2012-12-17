module Nightfury
  module Metric
    class TimeSeries < Base

      def initialize(name, options={})
        super(name, options={})
        init_time_series unless redis.exists(redis_key)
      end

      def set(value, time=Time.now)
        value = before_set(value)
        # make sure the time_series is initialized.
        # It will not if the metric is removed and 
        # set is called on the smae object
        init_time_series unless redis.exists(redis_key)
        add_value_to_timeline(value, time)
      end
      
      def get(timestamp=nil)
        return nil unless redis.exists(redis_key)
        data_point = ''
        if timestamp
          timestamp = timestamp.to_i
          data_point = redis.zrangebyscore(redis_key, timestamp, timestamp).first
        else
          data_point = redis.zrevrange(redis_key, 0, 0).first
        end

        time, data = decode_data_point(data_point)
        {time => data}
      end

      def get_range(start_time, end_time)
        return nil unless redis.exists(redis_key)        
        start_time = start_time.to_i
        end_time = end_time.to_i
        data_points = redis.zrangebyscore(redis_key, start_time, end_time)
        decode_many_data_points(data_points)
      end

      def get_all
        return nil unless redis.exists(redis_key)        
        data_points = redis.zrange(redis_key,1,-1)
        decode_many_data_points(data_points)         
      end

      def meta
        json = redis.zrange(redis_key, 0, 0).first
        JSON.parse(json)
      end

      def default_meta
        {}
      end

      private
      
      def add_value_to_timeline(value, time)
        time = time.to_i
        value = "#{time}:#{value}"
        redis.zadd redis_key, time, value
      end

      def decode_many_data_points(data_points)
        result = {}
        data_points.each do |data_point|
          time, data = decode_data_point(data_point)
          result[time] = data
        end
        result
      end

      def decode_data_point(data_point)
        colon_index = data_point.index(':')

        [
          data_point[0...colon_index], 
          data_point[colon_index+1..-1]
        ]
      end

      def before_set(value)
        value
      end

      def init_time_series
        redis.zadd redis_key, 0, default_meta.to_json
      end
    end
  end
end
