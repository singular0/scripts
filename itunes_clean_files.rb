#!/usr/bin/ruby

# Cleanup dir of files which are not added to iTunes library
# Copyright (C) 2016  Denis Yantarev <denis.yantarev@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "cgi"
require "optparse"
require "rexml/document"
require "rexml/streamlistener"
require "uri"

require "rubygems"
require "unicode"

class LibListener
  include REXML::StreamListener

  def initialize
    @is_key_tag = false
    @is_string_tag = false
    @is_location_key = false
    @files = []
  end

  def files
    @files
  end

  def tag_start(name, attrs)
    case name
      when "key"
        @is_key_tag = true
      when "string"
        @is_string_tag = true
    end
  end

  def tag_end(name)
    case name
      when "key"
        @is_key_tag = false
      when "string"
        @is_string_tag = false
    end
  end

  def text(text)
    if @is_key_tag
      @is_location_key = (text == "Location")
    elsif @is_string_tag && @is_location_key
      uri = URI::parse(text)
      filename = CGI::unescape(uri.path)
      filename = Unicode::downcase(filename) unless $options[:casesens]
      @files << filename
    end
  end
end

$orphan_count = 0

def process_dir(path, ll)
  count = 0
  Dir.foreach(path) do |f|
    next if f == "." || f == ".."
    orphan = false
    count += 1
    filename = File.join(path, f)
    if File.directory?(filename)
      n = process_dir(filename, ll)
      orphan = n == 0
    elsif File.file?(filename)
      s = $options[:casesens] ? filename : Unicode::downcase(filename)
      orphan = !ll.files.index(s)
    end
    if orphan
      $orphan_count += 1
      print "#{filename}\n" if $options[:verbose]
      if $options[:delete]
        File.delete(filename)
        count -= 1
      end
    end
  end
  count
end

$options = {}

optparser = OptionParser.new do |opts|
  opts.banner = "Usage: itunes_clean_files.rb [-c] [-d] [-v ] [-l library] path ..."
  $options[:libfile] = File.join(ENV["HOME"], "Music/iTunes/iTunes Music Library.xml")
  opts.on("-l", "--library LIBRARY", "iTunes Music Library.xml location override") do |file|
    $options[:libfile] = file
  end
  $options[:casesens] = false
  opts.on("-c", "--case-sensitive", "Storage filesystems are case-sensitive") do
    $options[:casesens] = true
  end
  $options[:delete] = false
  opts.on("-d", "--delete", "Delete files missing in the library database") do
    $options[:delete] = true
  end
  $options[:verbose] = false
  opts.on("-v", "--verbose", "Output names of orphan files") do
    $options[:verbose] = true
  end
  opts.on("-h", "--help", "Display this screen") do
    puts opts
    exit
  end
end

optparser.parse!

ll = LibListener.new
f = File.open($options[:libfile])
print "Parsing #{$options[:libfile]}...\n"
parser = REXML::Parsers::StreamParser.new(f, ll)
parser.parse
print "#{ll.files.count} files in library\n"
f.close

ARGV.each do |path|
  print "Processing #{path}...\n"
  process_dir(path, ll)
  operation = $options[:delete] ? "deleted" : "found"
  print "#{$orphan_count} orphan files #{operation}\n"
end
