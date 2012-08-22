#!/usr/bin/ruby

# Copyright (C) 2012 WU Jun <quark@zju.edu.cn>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'RRD'
require 'date'

INTERVALS      = [2, 24, 24 * 14] # unit: hour

HOST           = ARGV[0] || 'www.google.com'
RRD_FILE       = "ping_#{HOST.gsub('.','_')}.rrd"
RRD_GRAPH_FILE = "ping_#{HOST.gsub('.','_')}.png"
$0             = "pingstat_#{HOST}"


def ping(options)
    timeout = options[:timeout] || 1
    count = options[:count] || 1
    host = options[:host] || '127.0.0.1'

    rtt = packets = nil

    `ping -n -q -c #{count} -W #{timeout} #{host}`.each_line do |l|
        case l
        when /^(\d+) packets transmitted, (\d+) received/
            total, received = $~.captures.map(&:to_i)
            packets = { :total => total, :received => received, :loss => total - received }
        when /min\/avg\/max[^=]+= ([\d.]+)\/([\d.]+)\/([\d.]+)/
            min, avg, max = $~.captures.map(&:to_f)
            rtt = { :min => min, :max => max, :avg => avg }
        end
    end

    { :rtt => rtt,
      :packets => packets }
end

class DataFrame
    attr_accessor :total, :received, :avg

    def initialize
        self.total = self.received = self.avg = 0
    end

    def reset
        initialize
    end

    def to_s
        "packets: #{received}/#{total}, avg: #{avg}"
    end

    def update(stat)
        last_received = received

        if packets = stat[:packets]
            self.total += packets[:total]
            self.received += packets[:received]
        end

        if rtt = stat[:rtt]
            self.avg = (avg * last_received + rtt[:avg] * (received - last_received)) / received
        end
    end

    def packet_loss_percent
        100.0 * (total - received) / total
    end
end

def auto_unit(minutes)
  x = minutes > 1 ? minutes : 1

  [[[10080, 'WEEK'], [1440, 'DAY'], [60, 'HOUR'], [1, 'MINUTE']].find do |u|
    x >= u[0]
  end].map { |u| [x/u[0], u[-1], u[0], "#{u[1]}:#{x/u[0]}"] }.first
end

def draw_graph(rtt_upper_limit = 10)
    # I haven't find a way to let RRDTool auto scale
    # in this case. Thus, scale manually.
    right_axis_scale = 100.0 / rtt_upper_limit

    INTERVALS.each do |hours|
      name = lambda { |t| "#{t[0]}#{t[1].chars.first.downcase}" }[auto_unit(hours * 60)]
      x_grid = "#{auto_unit((hours*10+23)/24)[-1]}:" \
               "#{auto_unit((hours*60+23)/24)[-1]}:" \
               "#{auto_unit(hours*5)[-1]}:0:" + \
               (hours >= 144 ? '%b %d' : '%R')
      RRD.graph(
        RRD_GRAPH_FILE.gsub('.png', "_#{name}.png"), 
        '-w', 785, '-h', 120, '-a', 'PNG',
        '-Y', '-r', '-E',
        '--upper-limit', rtt_upper_limit,
        '--lower-limit', 0,
        '--start', "-#{hours * 3600}", '--end', 'now',
        '--font', 'DEFAULT:7:',
        '--title', "#{HOST} pingstat (#{name})",
        '--watermark', "\n#{DateTime.now.strftime('%c')}",
        '--vertical-label', 'latency (ms)',
        '--right-axis', "#{right_axis_scale}:0",
        '--right-axis-label', 'packet loss (%)',
        '--x-grid', x_grid,
        "DEF:roundtrip=#{RRD_FILE}:rtt:MAX",
        "DEF:packetloss=#{RRD_FILE}:pl:MAX",
        "CDEF:plscaled=packetloss,#{right_axis_scale},/",
        'LINE1:roundtrip#0000FF:latency (ms)',
        'AREA:plscaled#FF000099:packet loss (%)')
    end
end

def auto_scale(x)
    [5, 10, 20, 50, 100, 200, 500, 1000, 5000].each do |u|
        return u if x * 2 <= u
    end
    return 10000
end

# main logic
puts "Ping Graph for #{HOST}"

# create RRD graph
if not File.exists? RRD_FILE
    puts "Creating #{RRD_FILE}"
    RRD.create(
        RRD_FILE,
        '--step', '60',
        'DS:pl:GAUGE:120:0:100',
        'DS:rtt:GAUGE:120:0:10000000',
        'RRA:MAX:0.5:1:43200') # 43200: 60 * 24 * 30, 1 month
end


# ping loop
data = DataFrame.new
last_min = nil

loop do
    data.update(ping :host => HOST, :count => 3, :timeout => 4)

    now_min = Time.now.min
    if last_min != now_min
        last_min = now_min
        puts "Update: #{data}"
        RRD.update(
            RRD_FILE,
            '--template', 'pl:rtt',
            "N:#{data.packet_loss_percent}:#{data.avg}"
        )

        # draw graph
        draw_graph(auto_scale(data.avg))

        # reset ping counters
        data.reset
    end
end

