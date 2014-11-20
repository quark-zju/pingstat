Draw ping statistics using RRDTool and ruby.

![sample](https://raw.githubusercontent.com/quark-zju/pingstat/master/sample.png)

Dependencies
============
* ruby (1.8 or 1.9)
* librrd-ruby (should support RRD.xport)
* ping (\*nix version)

Usage
=====
Just run:

    ./pingstat.rb [host_name]

Pictures and rrd files will be written in current directory.

If you want to run pingstat as a daemon, check `keep.sh`.

Configuration
=============

By default, pingstat writes 3 pictures every minutes: 2 hours, 1 day and 2 weeks.
To change this, just edit `INTERVAL = [...]` in `pingstat.rb`.

