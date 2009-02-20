=begin
  * Name: govopml.rb
  * Description: Serves the opmls from govsdk
  * Author: Pito Salas
  * Copyright: (c) R. Pito Salas and Associates, Inc.
  * Date: January 2009
  * License: GPL

  This file is part of GovSDK.

  GovOpml is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  GovOpml is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty offset
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with GovOpml.  If not, see <http://www.gnu.org/licenses/>.
   => 
  require "ruby-debug"
  Debugger.settings[:autolist] = 1 # list nearby lines on stop
  Debugger.settings[:autoeval] = 1
  Debugger.start
  
=end
# If sinatra is included, then certain textmate debugger commands fail for unknown reasons.
include_sinatra = true

require 'rubygems'
if include_sinatra
  require 'sinatra'
end
require 'govsdkgem'
require 'opmlassist'

include Etc
include OpmlAssist
include REXML

CACHE_PATH = "cache"

if include_sinatra

  GovSdk.load_apis
  GovSdk.init :opensecrets => "09c975b6d3f19eb865805b2244311065", 
              :sunlight => "4ffa22917ab1ed010a8e681c550c9593",
              :google => "ABQIAAAAyvWaJgF_91PvBZhITx5FDxRIYAcXj39F4zFQfQ2X3IEFURxvMRRUi0aCG6WofnUSRRoI-Pgytm5yUA"

  get '/' do
    name = Pathname(".").realpath
    data = File.stat(".")
    cachedir = File.stat("cache")
    myself = getlogin
    "We (#{myself}) are here: #{name}, owner #{data.uid}, group #{data.gid}. Directory cache owner: #{cachedir.uid}, group #{cachedir.gid}" +
    " Process uid: #{Process.uid} gid: #{Process.gid}"
  end

  get '/congressmen/state/:state' do
    content_type 'text/xml'
    state = params[:state]
    # See if we already have this particular opml cached from today
    opml_file = check_cached_file("state-#{state}")
    if (opml_file.nil?)
      # Regenerate the opml file using GovSdk
      matching_congressmen = CongressPerson.find_by_query(:state => state)
      opml_file = update_cached_file("state-#{state}")
      generate_opml(matching_congressmen, opml_file)
    end
    send_file opml_file.expand_path
  end

  get '/congressmen/party/:party' do
    content_type 'text/xml'
    "Generating state OPML for #{params[:party]}"
  end
end

def generate_opml(congmen, filepath)
  opml = Opml.new("Congressmen", "Their Feeds", {:namespace => {:namespace => "xmlns:bb", :value => "http://blogbridge.com/ns/2006/opml"}})
  counter = 0
  congmen.each do |cm|
    blog = cm.blog_url
    if (blog.nil?)
      counter += 1
    else
      puts "Processed #{cm.firstname} #{cm.lastname}"
      opml.feeds << Feed.new("#{cm.firstname} #{cm.lastname}", "rss", blog)
    end
  end
  puts "missing blogs: #{counter}"
  new_opml_file = File.new(filepath, "w")
  opml.xml.write(new_opml_file, 1)
  new_opml_file.close
end

# Look in CACHE_PATH for a file called filename--date.opml. Check if the file was created earlier 
# than today. If file is recent, return it, otherwise return nil
def check_cached_file(target_name)
  cachefiles = Pathname.new(CACHE_PATH)
  cachefiles.each_entry do |entry| 
    # In cache, each file name ends with the date in text, e.g. filename--jan-12-2009
    next if entry.directory?
    name, days_ago = analyze_file_name(entry.to_s)
    if !name.nil? && name == target_name && days_ago <= 1
      return (Pathname.new(CACHE_PATH)+entry)
    end
  end
end

# Given a filename like: "do-cand--feb-15-2009.opml", returns two results, 
# the filename ("do-cand") and the number of days ago the date is.
def analyze_file_name(cand_path)
  # split into an array of 3 strings at '--' and ".". Return if there aint no "--"
  scan_result = cand_path.scan(/(.*)--(.*)\.(.*)/)[0]
  return nil, nil if scan_result.nil?
  
  # second part is date of the file. See how many days before today that date is
  dstamp = scan_result[1]
  date_of_file = Date.parse(dstamp)
  days_apart = (DateTime.now - date_of_file).to_i
  return scan_result[0], days_apart
end 

# Delete files in CACHE_PATH called filename.*. 
# Create a new one, called filename--todaysdate and return it.
def update_cached_file(target_name)
  cachefiles = Pathname.new(CACHE_PATH)
  cachefiles.each_entry do |entry|
    # Skip over directories
    next if entry.directory?
    # In cache, each file name ends with the date in text, e.g. filename--jan-12-2009
    name, days_ago = analyze_file_name(entry.to_s)
    if !name.nil? && name == target_name
      (Pathname.new(CACHE_PATH)+entry).delete
    end
  end
  Pathname.new("#{CACHE_PATH}/#{cached_file_name_string(target_name)}.opml")
end

# string used for naming files in cache. Combines the name with today's date.
def cached_file_name_string(filename)
  "#{filename}--#{Time.now.strftime('%d%b%Y')}"
end
  
if $0 == __FILE__  && !include_sinatra
  require 'test/unit'
  require 'shoulda'
  require 'mocha'
  require 'pp'
  
  class GovOpmlTest < Test::Unit::TestCase
     context "testing analyze_file_name" do
       setup do
       end

       should "filename without .opml fails" do
         name, ago = analyze_file_name("pito-salas--feb-15-2009")
         assert name.nil?
       end
       
       should "filename without date should also fail" do
         name, ago = analyze_file_name("pito-salas.opml")
         assert name.nil?
       end
       
       should "correctly analyze a valid filename" do
         name, ago = analyze_file_name("pito-salas--12jan2009.opml")
         assert_equal "pito-salas", name
         assert ago > 0
       end
     end

     context "caching utilities" do
       setup do
       end

       should "work when there's no cache file yet" do
         new_cached = update_cached_file("pito-salas")
         assert_equal File, new_cached.class
         file_name = File.basename(new_cached.path)
         scan_result = file_name.scan(/(.*)--(.*)\.(.*)/)
         assert_equal "pito-salas", scan_result[0][0]
         assert_equal "opml", scan_result[0][2]    
      end
      
      should "work when there is already a cache file" do
        new_cached = create_cached_file("pito-salas")
        assert_equal File, new_cached.class
        file_name = File.basename(new_cached.path)
        scan_result = file_name.scan(/(.*)--(.*)\.(.*)/)
        assert_equal "pito-salas", scan_result[0][0]
        assert_equal "opml", scan_result[0][2]
      end
    end
  end
end