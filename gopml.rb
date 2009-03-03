=begin
  * Name: govopml.rb
  * Description: Serves the opmls from govsdk
  * Author: Pito Salas
  * Copyright: (c) 2009 R. Pito Salas and Associates, Inc.
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
require 'coldcache'

include Etc
include OpmlAssist
include REXML

if include_sinatra

  GovSdk.load_apis
  GovSdk.init :opensecrets => "09c975b6d3f19eb865805b2244311065", 
              :sunlight => "4ffa22917ab1ed010a8e681c550c9593",
              :google => "ABQIAAAAyvWaJgF_91PvBZhITx5FDxRIYAcXj39F4zFQfQ2X3IEFURxvMRRUi0aCG6WofnUSRRoI-Pgytm5yUA"
  set :opml_cache, ColdCache.new("cache", ".opml")

#
# Root of site is intro page
#
  get '/' do
    haml :intro
  end

# Various debugging paths

# Document the options
  get '/debug' do
    haml :comingsoon
  end

# Display the path the app is on  
  get '/debug/status' do
    @name = Pathname(".").realpath
    @data = File.stat(".")
    @cachedir = options.opml_cache.stat
    @myself = getlogin
    haml :status
  end

# Dump out the sinatra log  
  get '/debug/log' do
    haml :comingsoon
  end

# Reset the sinatra log  
  get '/debug/log/reset' do
    haml :comingsoon
  end
  
# Intro for congressional info
  get '/congress' do
    haml :stateintro
  end

# Intro for congressional, by state info
  get '/congress/state' do
    haml :stateintro
  end
  
#
# Return stylesheet by processing sass
#
  get '/stylesheets/application.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :application
  end
  
#
# Display a list of the congresspeople and some info about each one
#
get '/congress/state/:state' do
  @matching_state = params[:state]
  @proper_state_name = Util.lookup_state_name(@matching_state)
  @matching_congpeople = CongressPerson.find_by_query(:state => @matching_state)
  haml :cong_people
end

#
# Basic OPML for a list of congressional blogs. Check if cached instance already exists,
# if not, then generate it.
#
  get '/congress/state/:state.opml' do
    state = params[:state]
    proper_state_name = Util.lookup_state_name(state)
    not_found "Unknown state code: '#{state}'. Use one of the standard USPS 2 letter state codes" if proper_state_name.nil?
    redirect "/congress/state/#{proper_state_name}.opml" if state != proper_state_name

    # Build the opml response
    content_type 'text/xml'  
    # See if we already have this particular opml cached from today
    opml_file = options.opml_cache.check_cached_file("state-#{state}")
    if (opml_file.nil?)
      # Regenerate the opml file using GovSdk
      matching_congressmen = CongressPerson.find_by_query(:state => state)
      opml_file = options.opml_cache.update_cached_file("state-#{state}")
      generate_opml(matching_congressmen, opml_file)
    end
    send_file opml_file.expand_path
  end

#
# List of congressional blogs. per party, as opml. Not yet implemented.
#
  get '/congress/party/:party' do
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

if $0 == __FILE__  && !include_sinatra
  require 'test/unit'
  require 'shoulda'
  require 'mocha'
  require 'pp'
  
  class GopmlTest < Test::Unit::TestCase
     context "testing analyze_file_name" do
       setup do
       end

       should "filename without .opml fails" do
         assert true
       end
    end
  end
end