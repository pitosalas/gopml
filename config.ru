#  * Name: config.ru
#  * Description: Passanger/Sinatra launch file for Rack (or something like that :)
#  * Author: Pito Salas
#  * Copyright: (c) R. Pito Salas and Associates, Inc.
#  * Date: January 2009
#  * License: GPL
#
#  This file is part of GovOpml.
#
#  GovOpml is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  GovOpml is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with GovOpml.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'govopml.rb'

set :env, :production
disable :run


log = File.new("sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)
run Sinatra.application
