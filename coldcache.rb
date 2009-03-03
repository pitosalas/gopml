=begin
  * Name: ColdCache.rb
  * Description: Standard header for all source files
  * Author: Pito Salas
  * Copyright: (c) R. Pito Salas and Associates, Inc.
  * Date: January 2009
  * License: GPL

  This file is part of Gopml. (It will become a gem at some point.)

  GovOpml is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  GovOpml is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with GovOpml.  If not, see <http://www.gnu.org/licenses/>.
  
  require "ruby-debug"
  Debugger.settings[:autolist] = 1 # list nearby lines on stop
  Debugger.settings[:autoeval] = 1
  Debugger.start
  
=end
require 'rubygems'

# A way simple utility to manage a directory of files serving as a cache. All files live in the indicated cachepath
# and have a name that looks like this:
#
#   <filename>--<date-created>.<extension>
#
# so for example, image-file--oct-2-2009.gif
#
# There are methods for:
## doing a cache lookup for a file in the cache that is up to date, which means, created today
## creating a new file in the cache that will be marked with today's date.
#

class ColdCache
  
# path is relative to where we are, for the directory containing the cache files
# extension is String, e.g. ".doc", for extension of file in this cache
  def initialize(cachepath, extension)
    raise ArgumentError, 'Extension must start with one dot' unless extension =~ /\A\.\w+/
    raise ArgumentError, 'path must be a string' unless cachepath.kind_of? String
    @path = cachepath
    @extension = extension
    @path_name = Pathname.new(@path)
# Check if the cache directory exists, and if it doesn't, then create it
    @path_name.mkdir unless @path_name.directory?
  end

# Return File.stat for the directory containing the cached files
  def stat
    File.stat("cache")
  end
  
# Look in cache for a file called filename--date.opml. Check if the file was created earlier 
# than today. If file is recent, return it, otherwise return nil
  def check_cached_file(target_name)
    cachefiles = @path_name
    cachefiles.each_entry do |entry| 
      # In cache, each file name ends with the date in text, e.g. filename--jan-12-2009
      next if entry.directory?
      name, days_ago = analyze_file_name(entry.to_s)
      if !name.nil? && name == target_name && days_ago <= 1
        return @path_name+entry
      end
    end
  end
  
# Given a filename like: "abc--feb-15-2009.uau", returns two results, 
# the filename ("abc") and the number of days ago the date is (that is it returns 2 values)
  def analyze_file_name(filename)
    # split into an array of 3 strings at '--' and ".". Return if there aint no "--", 
    # Or if the extension is not the one that this cache uses.
    scan_result = filename.scan(/(.*)--(.*)\.(.*)/)[0]
    return nil, nil if scan_result.nil?
    return nil, nil if "." + scan_result[2] != @extension

    # second part is date of the file. See how many days before today that date is
    dstamp = scan_result[1]
    date_of_file = Date.parse(dstamp)
    days_apart = (DateTime.now - date_of_file).to_i
    return scan_result[0], days_apart
  end 
  
# Delete files in the cache called filename.*. 
# Create a new filename (not the actual file), for new cache entry: filename--todaysdate.ext and return it.
  def update_cached_file(filename)
    @path_name.each_entry do |entry|
      # Skip over directories
      next if entry.directory?
      # In cache, each file name ends with the date in text, e.g. filename--jan-12-2009
      name, days_ago = analyze_file_name(entry.to_s)
      if !name.nil? && name == filename
        (pathname+entry).delete
      end
    end
    Pathname.new("#{@path}/#{cached_file_name_string(filename)}#{@extension}")
  end
  
  # Construct the string used for naming files in cache. Combines the name with today's date.
  def cached_file_name_string(filename)
    "#{filename}--#{Time.now.strftime('%d%b%Y')}"
  end
  
end

if $0 == __FILE__
  require 'test/unit'
  require 'shoulda'
  require 'mocha'
  require 'pp'
  
  class ColdCacheTest < Test::Unit::TestCase
    context "testing coldCache" do
     setup do
       @a_cache = ColdCache.new("funny",".zoo")
     end
     
     should "catch error cases" do
       assert_raise ArgumentError  do
         ColdCache.new("funny", "no_dot")
       end
       assert_raise ArgumentError do
         ColdCache.new(12, ".dot")
       end       
       assert_nothing_raised do
         ColdCache.new("string", ".doc")
       end
     end

     should "properly analyze file name without .zoo" do
       name, ago = @a_cache.analyze_file_name("pito-salas--feb-15-2009")
       assert name.nil?
     end
     
      should "also detect if the extension is the wrong one" do
       name, ago = @a_cache.analyze_file_name("pito-salas--feb-15-2009.car")
       assert name.nil?
      end
    
      should "filename without date should also fail" do
        name, ago = @a_cache.analyze_file_name("pito-salas.zoo")
        assert name.nil?
      end
    
      should "correctly analyze a valid filename" do
        name, ago = @a_cache.analyze_file_name("pito-salas--12jan2009.zoo")
        assert_equal "pito-salas", name
        assert ago > 0
      end
      
			should "work when there's no cache file yet" do
	      new_cached = @a_cache.update_cached_file("pito-salas")
	      assert_equal Pathname, new_cached.class
	      scan_result = new_cached.basename.to_s.scan(/(.*)--(.*)\.(.*)/)
	      assert_equal "pito-salas", scan_result[0][0]
	      assert_equal "zoo", scan_result[0][2]    
	    end
  end
 end
end
