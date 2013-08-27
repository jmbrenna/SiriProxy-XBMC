# Copyright (C) 2011 by Rik Halfmouw <rik@iwg.nl>
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

require 'cora'
require 'siri_objects'
require 'xbmc_library'
require 'pp'

#######
# This is plugin to control XBMC
# Remember to configure the host and port for your XBMC computer in config.yml in the SiriProxy dir
######

class SiriProxy::Plugin::XBMC < SiriProxy::Plugin
  def initialize(config)
    appname = "SiriProxy-XBMC"
    host = config["xbmc_host"]
    port = config["xbmc_port"]
    username = config["xbmc_username"]
    password = config["xbmc_password"]
    

    @roomlist = Hash["default" => Hash["host" => host, "port" => port, "username" => username, "password" => password]]

    rooms = File.expand_path('~/.siriproxy/house_config.yml')
    if (File::exists?( rooms ))
      @roomlist = YAML.load_file(rooms)
    end
      
    @active_room = @roomlist.keys.first

    @xbmc = XBMCLibrary.new(@roomlist, appname)
      
  end
    
  #show plugin status
  listen_for /[xX] *[bB] *[mM] *[cC] *(.*)/i do |roomname|
    roomname = roomname.downcase.strip
    roomcount = @roomlist.keys.length

    if (roomcount > 1 && roomname == "")
      say "Here are the rooms where you have XBMC, and their current status."

      @roomlist.each { |name,room|
        if (@xbmc.has_xbmc(name) == true)
            if (@xbmc.connect(name))
                say "#{name.titleize}: Online", spoken: "The #{name} is online"
            else
                say "#{name.titleize}: Offline", spoken: "The #{name} is offline"
            end
        end
      }
    else
      if (roomname == "")
        roomname = @roomlist.keys.first
      end
      if (roomname != "" && roomname != nil && @roomlist.has_key?(roomname))
        if (@xbmc.connect(roomname))
          say "XBMC is online"
        else 
          say "XBMC is offline, please check the plugin configuration and check if XBMC is running"
        end
      else
        say "There is no room defined called \"#{roomname}\""
      end
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

listen_for /^(?:How do I|How can I|What can I|Do I|How I|How are you|Show the commands for|Show the commands to|What are the commands for) (?:control |do with |controlling |do at )?(?:the)? (?:media|media library|media center)/i do
    say "Here are the commands for controlling Media Library:\n\nQuery all rooms with XBMC and what is the current status:\n  \"XBMC\"\n\nShow the Weather:\n  \"Show the Weather\"\n\nOpen Netflix/Hulu:\n  \"Open Netflix/Hulu\"\n\nGo to the Home Screen:\n  \"Go to home screen\"\n\nShow recently added movies:\n  \"Show recently added movies\"\n\nShow recently added TV Shows:\n  \"Show recently added TV shows\"\n\nSearch for media titles within the entire media library:\n  \"Search for \[Title\]\"\n\nSearch for media titles within Movie media only:\n  \"Search for movies called \[Title\]\"\n\nSearch for media titles within TV Shows media only:\n  \"Search for TV shows called \[Title\]\"\n\nSearch for TV show titles within TV Shows media only:\n  \"Search for TV episodes called \[Title\]\"\n\nPlay a specific media title from the entire media library:\n  \"Play \[Unique Title\]\"\n\nPlay the last unwatched TV episode from a TV series\n  \"Play \[TV Show Title\]\"\n\nPlay the latest TV episode from a TV series:\n  \"Play the latest \[TV Show Title\]\"\n\nPlay a random TV episode from a TV series:\n  \"Play a random \[TV Show Title\]\"\n\nPlay a movie, only looking in the movie media library:\n  \"Play \[Movie Title\]\"\n\nStop the Media Player:\n  \"Stop\"\n\nPause the Media Player:\n  \"Pause\"\n\nResume the Media Player:\n  \"Resume\"",spoken: "Here are the commands for controlling the Media Library"
    request_completed
end

    listen_for /^stop/i do
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                if @xbmc.stop()
                    @xbmc.open_home()
                    say "I stopped the media player"
                    else
                    say "There is no media playing"
                end
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end

    # stop playing
    listen_for /^([Ll]aunch|[Oo]pen|[Ss]how) [Nn]etflix/i do
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                @xbmc.open_netflix()
                say "Opened Netflix."
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end

    listen_for /^([Ll]aunch|[Oo]pen|[Ss]how) [Hh]ulu/i do
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                @xbmc.open_hulu()
                say "Opened Hulu."
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end
    listen_for /^([Ll]aunch|[Oo]pen|[Ss]how) [Pp]lex/i do
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                @xbmc.open_plex()
                say "Opened Plex."
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end
    listen_for /^([Ll]aunch|[Oo]pen|[Ss]how)(?: the)? [Ww]eather/i do
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                @xbmc.open_weather()
                say "Here is the weather."
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end        
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end
    listen_for /^([Ll]aunch|[Oo]pen|[Ss]how|[Gg]o to|[Gg]o)(?: the)? [Hh]ome(?: screen)?/i do
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                @xbmc.open_home()
                say "Opened Home Screen"
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end
listen_for /^[Ss]earch for (?:the )?(movies |movie |TV shows |TV show |TV episode |TV episodes |episodes |episode )?(?:of )?(?:called |call |name |named |titled |title )?(.*)$/i do |subject,searchphrase|
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = @xbmc.find_active_room(deviceMAC)
        if (subject == nil)
            subject = "all"
        elsif (subject == "movies " || subject == "movie ")
            subject = "movie"
        elsif (subject == "TV shows " || subject == "TV show ")
            subject = "tvshows"
        elsif (subject == "TV episodes " || subject == "TV episode " || subject == "episode " || subject == "episodes ")
            subject = "tvepisodes"
        elsif (subject == "seasonsTVEpisodes")
            subject == "seasonsTVEpisodes"
            searchmodphrase = "season_#{seasonNumber}_#{searchphrase}"
        end
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        else
            @active_room = currentLoc
        end
        if (@xbmc.has_xbmc(@active_room) == true)
            if (@xbmc.connect(@active_room))
                @xbmc.xbmc_close()
                if (subject == "seasonsTVEpisodes")
                    @xbmc.xbmc_search(searchmodphrase,subject)
                else
                    @xbmc.xbmc_search(searchphrase,subject)
                end
                say "Here are the results for #{searchphrase}"
            end
        else
            say "There is no XBMC player in the #{@active_room}"
        end
        request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end

  # pause playing
  listen_for /^pause/i do
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
      currentLoc = @xbmc.find_active_room(deviceMAC)
      if (currentLoc == false)
          say "I don't know where you are.  Please tell me what room you are in."
      else
          @active_room = currentLoc
      end
    if (@xbmc.has_xbmc(@active_room) == true)
        if (@xbmc.connect(@active_room))
            if @xbmc.pause()
                say "I paused the media player"
            else
                say "There is no media playing"
            end
        end
    else
        say "There is no XBMC player in the #{@active_room}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  # scan
  listen_for /^(?:[S|s]can|[S|]cam)/i do
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
      currentLoc = @xbmc.find_active_room(deviceMAC)
      if (currentLoc == false)
          say "I don't know where you are.  Please tell me what room you are in."
      else
          @active_room = currentLoc
      end
    if (@xbmc.has_xbmc(@active_room) == true)
        if (@xbmc.connect(@active_room))
            if @xbmc.scan()
                say "I'm scanning for new content"
            else
                say "There was a problem scanning for new content"
            end
        end
    else
        say "There is no XBMC player in the #{@active_room}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  listen_for /^[C|c]lean (video|audio) library/i do |media|
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
    currentLoc = @xbmc.find_active_room(deviceMAC)
    if (currentLoc == false)
        say "I don't know where you are.  Please tell me what room you are in."
        else
        @active_room = currentLoc
    end
    if (@xbmc.has_xbmc(@active_room) == true)
        if (@xbmc.connect(@active_room))
            if (media == "video")
                if @xbmc.clean_VideoLibrary()
                    say "I'm cleaning your video library"
                else
                    say "There was a problem scanning for new content"
                end
            end
            if (media == "audio")
                if @xbmc.clean_AudioLibrary()
                    say "I'm cleaning your audio library"
                else
                    say "There was a problem scanning for new content"
                end
            end
        end
        else
        say "There is no XBMC player in the #{@active_room}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  # recently added movies
  listen_for /recent.*movie(?:s)?/i do
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
      currentLoc = @xbmc.find_active_room(deviceMAC)
      if (currentLoc == false)
          say "I don't know where you are.  Please tell me what room you are in."
      else
          @active_room = currentLoc
      end
    if (@xbmc.has_xbmc(@active_room) == true)
        if (@xbmc.connect(@active_room))
            @xbmc.xbmc_close()
            data = @xbmc.get_recently_added_movies()
            say "Here are your recently added movies"
        end
    else
        say "There is no XBMC player in the #{@active_room}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  # recently added episodes
  listen_for /recent.*tv/i do
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
      currentLoc = @xbmc.find_active_room(deviceMAC)
      if (currentLoc == false)
          say "I don't know where you are.  Please tell me what room you are in."
      else
          @active_room = currentLoc
      end
    if (@xbmc.has_xbmc(@active_room) == true)
        if (@xbmc.connect(@active_room))
            @xbmc.xbmc_close()
            data = @xbmc.get_recently_added_episodes()
            say "Here are your recently added TV episodes"
        end
    else
        say "There is no XBMC player in the #{@active_room}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  # resume playing
  listen_for /^resume|unpause|continue/i do
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
      currentLoc = @xbmc.find_active_room(deviceMAC)
      if (currentLoc == false)
          say "I don't know where you are.  Please tell me what room you are in."
      else
          @active_room = currentLoc
      end
    if (@xbmc.has_xbmc(@active_room) == true)
        if (@xbmc.connect(@active_room))
            #@xbmc.xbmc_close()
            if @xbmc.pause()
                say "I resumed the media player", spoken: "Resuming media"
            else
                say "There is no media playing"
            end
        end
    else
        say "There is no XBMC player in the #{@active_room}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  listen_for /^Where am [I|i]/i do
      deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
      currentLoc = @xbmc.find_active_room(deviceMAC)
      if (currentLoc == false)
          say "I don't know.  Please tell me what room you are in."
      else
          say "You are in the #{currentLoc}"
      end
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  listen_for /^What rooms are available/i do
    say "The currently available rooms are:"
          
    @roomlist.each { |name,room|
        if (name != "house")
            say "#{name}"
        end
    }
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  listen_for /^(?:What|Which) room(?: am )?[I|i] in/i do
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
    currentLoc = @xbmc.find_active_room(deviceMAC)
    if (currentLoc == false)
        say "I don't know.  Please tell me what room you are in."
        else
        say "You are in the #{currentLoc}"
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

listen_for /^(?:What|Which) (?:services are available|service are available)(?: in)?(?: the | my )?(.*)/i do |roomname|
    roomname = roomname.downcase.strip
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
    if (roomname == "")
        roomname = @xbmc.find_active_room(deviceMAC)
        roomname = roomname.downcase.strip
    end
    if (roomname != nil && @roomlist.has_key?(roomname))
        say "Here is what you can control in the #{roomname}:"
        @roomlist[roomname].each { |name,service|
            if (name == "xbmc")
                name = "media"
            end
            say "#{name.capitalize}"
        }
    else
        say "There is no room defined called \"#{roomname}\""
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  # set default room
  listen_for /^(?:(?:[Ii]'m in)|(?:[Ii] am in)|(?:[Uu]se)|(?:[Cc]ontrol)) the (.*)/i do |roomname|
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
    roomname = roomname.downcase.strip
    if (roomname == "house")
        roomname = "9999999999"
    end
    if (roomname != "" && roomname != nil && @roomlist.has_key?(roomname))
      @xbmc.update_room(deviceMAC,roomname)
      @active_room = roomname
      say "Noted.", spoken: "Commands will be sent to the \"#{roomname}\""
    else
      if (roomname == "9999999999")
        roomname = "house"
      end
      say "There is no room defined called \"#{roomname}\""
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end
                

  #play movie or episode
  listen_for /^(?:P|p)lay (the movie|movie|the latest episode of|the latest episode|the latest|latest|the most recent episode of|the most recent episode|the most recent|most recent|most recently aired|a random|random|the)?(.+?)(?: episode)?$/i do |episodequantifier,title|
    deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
    currentLoc = @xbmc.find_active_room(deviceMAC)
                  puts title
    if (currentLoc == false)
        say "I don't know where you are.  Please tell me what room you are in."
    else
        @active_room = currentLoc
    end
    if (@xbmc.has_xbmc(@active_room) == true)
    series = "fdsajfldajsffdsafdsakldjsakfj"
    if (@xbmc.connect(@active_room))
      @xbmc.xbmc_close()
      if title.include?(" from ")
        origtitle = title
        title, series = title.split(" from ")
      end
      if (episodequantifier == "movie" || episodequantifier == "the movie" || title == "selected")
        tvshow = ""
      else
		if (series != "fdsajfldajsffdsafdsakldjsakfj")
			tvshow = @xbmc.find_show(series)
			if (tvshow == "" || series == "")
				tvshow = @xbmc.find_show(origtitle)
			end
		else
			tvshow = @xbmc.find_show(title)
		end
      end
      if (tvshow == "")
        movie = @xbmc.find_movie(title)
        if (movie == "")
		  if (episodequantifier == "movie" || episodequantifier == "the movie")
			say "Movie title not found, please try again"
            request_completed #always complete your request! Otherwise the phone will "spin" at the user!            
		  else
			episode = @xbmc.find_episode(title)
			if (episode == "")
				say "Title not found, please try again"
                request_completed #always complete your request! Otherwise the phone will "spin" at the user!
			else
				say "Now playing \"#{episode["title"]}\" (#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]})", spoken: "Now playing \"#{episode["title"]}\""
                request_completed #always complete your request! Otherwise the phone will "spin" at the user!
				@xbmc.play(episode["file"])
			end
		  end
        else
          say "Now playing \"#{movie["title"]}\"", spoken: "Now playing \"#{movie["title"]}\""
          request_completed #always complete your request! Otherwise the phone will "spin" at the user!
          @xbmc.play(movie["file"])
        end
      else
        if (episodequantifier == "the latest" || episodequantifier == "latest" || episodequantifier == "most recently aired" || episodequantifier == "the latest episode of" || episodequantifier == "latest episode" || episodequantifier == "most recent" || episodequantifier == "the most recent" || episodequantifier == "the most recent episode of" || episodequantifier == "the most recent episode")
          episode = @xbmc.find_latest_episode(tvshow["tvshowid"])
        elsif (episodequantifier == "random" || episodequantifier == "a random")
          episode = @xbmc.find_random_episode(tvshow["tvshowid"])
        elsif (series != "fdsajfldajsffdsafdsakldjsakfj")
          episode = @xbmc.find_series_and_episode(tvshow["tvshowid"],title)
        else
          episode = @xbmc.find_first_unwatched_episode(tvshow["tvshowid"])
        end
        if (episode == "")
          say "No unwatched episode found for the \"#{tvshow["label"]}\""
          request_completed #always complete your request! Otherwise the phone will "spin" at the user!
        else
          say "Now playing \"#{episode["title"]}\" (#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]})", spoken: "Now playing \"#{episode["title"]}\""
          request_completed #always complete your request! Otherwise the phone will "spin" at the user!
          @xbmc.play(episode["file"])
        end
      end
    else 
      say "The XBMC interface is unavailable, please check the plugin configuration or check if XBMC is running"
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    end
    else
        say "There is no XBMC player in the #{@active_room}"
    end
  end

  
end
