Draw ping statistics using RRDTool and ruby.

![sample](/quark-zju/pingstat/raw/master/sample.png)

Dependencies
============
* ruby
* librrd-ruby
* ping

Usage
=====
Just run:

    ./pingstat.rb [host_name]

Pictures and rrd files will be written in current directory.

If you want to run pingstat as a daemon, check `keep.sh`.

Configuration
=============

By default, pingstat writes 3 pictures every minutes: 2 hours, 1 day and 1 week.
To change this, just edit `INTERVAL = [...]` in `pingstat.rb`.

