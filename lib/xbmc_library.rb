require 'httparty'
require 'active_support/core_ext'
require 'json'
require 'open-uri'

class XBMCLibrary
  # Error class for indicating trouble with authentication against the XBMC Api
  class UnauthorizedError < StandardError; end;
  
  include HTTParty

  def initialize(serverlist, appname)
    @xbmc = serverlist
    @appname = appname
  end
  def has_xbmc(location)
      if(@xbmc[location]["xbmc"] == nil)
          return false
      else
          return true
      end
  end

  def set_xbmc_config(location="default")
    if (!@xbmc.has_key?(location) || !@xbmc[location]["xbmc"].has_key?("host") || !@xbmc[location]["xbmc"]["host"] == "")
      puts "[#{@appname}] No host configured for #{location}."
      return false
    end
    self.class.base_uri "http://#{@xbmc[location]["xbmc"]["host"]}:#{@xbmc[location]["xbmc"]["port"]}"
    self.class.basic_auth @xbmc[location]["xbmc"]["username"], @xbmc[location]["xbmc"]["password"]

    return true
  end


  # API interaction: Invokes the given method with given params, parses the JSON response body, maps it to
  # a HashWithIndifferentAccess and returns the :result subcollection
  def xbmc(method, params={})
    JSON.parse(invoke_json_method(method, params).body).with_indifferent_access[:result]
  end
    
  # Raw API interaction: Invoke the given JSON RPC Api call and return the raw response (which is an instance of
  # HTTParty::Response)
  def invoke_json_method(method, params={})
    response = self.class.post('/jsonrpc', :body => {"jsonrpc" => "2.0", "params" => params, "id" => "1", "method" => method}.to_json,:headers => { 'Content-Type' => 'application/json' } )    
raise XBMCLibrary::UnauthorizedError, "Could not authorize with XBMC. Did you set up the correct user name and password ?" if response.response.class == Net::HTTPUnauthorized
    response
      
    # Capture connection errors and send them out with a custom message
    rescue Errno::ECONNREFUSED, SocketError, HTTParty::UnsupportedURIScheme => err
    raise err.class, err.message + ". Did you configure the url and port for XBMC properly using Xbmc.base_uri 'http://localhost:1234'?"
  end


  def test()
    return xbmc('VideoLibrary.GetRecentlyAddedMovies')
  end

  def find_active_room(macaddress)
      location = ""
      filename = macaddress.gsub(":","")
      filename = filename.gsub("\n","")
      filename = "#{filename}.siriloc"
      if (!File.exists?("#{filename}"))
          return false
      else
          File.open(filename).read.split("\n").each do |line|
              location = line
          end
          return location
      end
  end

  def update_room(macaddress,location)
      filename = macaddress.gsub(":","")
      filename = filename.gsub("\n","")
      filename = "#{filename}.siriloc"
      File.open(filename, "w") do |locfile|
          locfile << location
      end
  end
    
  def connect(location)
    puts "[#{@appname}] Connecting to the XBMC interface (#{location})"
    $apiLoaded = false
    begin
      if (set_xbmc_config(location))
        $apiVersion = ""
        $apiVersion = xbmc('JSONRPC.version')

        if ($apiVersion["version"]["major"] == 2)
          puts "[#{@appname}] XBMC API Version #{$apiVersion["version"]["major"]} - Dharma"
        elsif ($apiVersion["version"]["major"] == 6)
          puts "[#{@appname}] XBMC API Version #{$apiVersion["version"]["major"]} - Frodo"
        else
            puts "[#{@appname}] XBMC API Version #{$apiVersion["version"]["major"]} - Eden"
        end
        $apiLoaded = true
      end
    rescue
      puts "[#{@appname}] An error occurred: #{$!}"
    end
    return $apiLoaded
  end

  def get_media_player()
    puts "[#{@appname}] Get active video player (API version #{$apiVersion["version"]})"
    result = ""
    if ($apiVersion["version"] == 2)
      players = xbmc('Player.GetActivePlayers')
      result = players
    else
      players = xbmc('Player.GetActivePlayers')
        if (players.length == 1)
            players.each { |player|
                result = player["playerid"]
            }
        end
        #players.each { |player|
        #if (player["type"] == "video")
        #  result = player["playerid"]
        #end
        #}
    end
    return result
  end

  def find_movie(title)
    puts "[#{@appname}] Finding movie (API version #{$apiVersion["version"]})"
    result = ""
    title = title.downcase.gsub(/[^0-9A-Za-z]/, '')
    if ($apiVersion["version"] == 2)
      movies = xbmc('VideoLibrary.GetMovies', { :fields => ["file", "genre", "director", "title", "originaltitle", "runtime", "year", "playcount", "rating", "lastplayed"] })["movies"]
    else
      movies = xbmc('VideoLibrary.GetMovies', { :properties => ["file", "genre", "director", "title", "originaltitle", "runtime", "year", "playcount", "rating", "lastplayed"] })["movies"]
    end
    movies.each { |movie|

      movietitle = movie["label"].downcase.gsub(/[^0-9A-Za-z]/, '')

      if movietitle.match(title)
        return movie
      end
    }
    return result
  end

  def find_show(title)
    puts "[#{@appname}] Finding TV show (API version #{$apiVersion["version"]})"
    result = ""
    title = title.downcase.gsub(/[^0-9A-Za-z]/, '')
    if ($apiVersion["version"] == 2)
      tvshows = xbmc('VideoLibrary.GetTVShows')["tvshows"]
    else
      tvshows = xbmc('VideoLibrary.GetTVShows')["tvshows"]
    end
    tvshows.each { |tvshow|

      tvshowtitle = tvshow["label"].downcase.gsub(/[^0-9A-Za-z]/, '')

      if tvshowtitle.match(title)
        return tvshow
      end
    }
    return result
  end
    
    def find_episode(title)
        puts "[#{@appname}] Finding TV episode (API version #{$apiVersion["version"]})"
        result = ""
        title = title.downcase.gsub(/[^0-9A-Za-z]/, '')
        if ($apiVersion["version"] == 2)
            episodes = xbmc('VideoLibrary.GetEpisodes', { :fields => ["title", "showtitle", "season", "episode", "file"] } )["episodes"]
            else
            episodes = xbmc('VideoLibrary.GetEpisodes', { :properties => ["title", "showtitle", "season", "episode", "file"] } )["episodes"]
        end
        episodes.each { |episode|
            
            episodetitle = episode["title"].downcase.gsub(/[^0-9A-Za-z]/, '')
            
            if episodetitle.match(title)
                return episode
            end
        }
        return result
    end
    
    def find_series_and_episode(tvshowid,title)
        puts "[#{@appname}] Finding TV episode and series (API version #{$apiVersion["version"]})"
        result = ""
        title = title.downcase.gsub(/[^0-9A-Za-z]/, '')
        if ($apiVersion["version"] == 2)
            episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :fields => ["title", "showtitle", "season", "episode", "file"] } )["episodes"]
            else
            episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :properties => ["title", "showtitle", "season", "episode", "file"] } )["episodes"]
        end
        if (episodes == nil)
            return ""
        end
        episodes.each { |episode|
            
            episodetitle = episode["title"].downcase.gsub(/[^0-9A-Za-z]/, '')
            
            if episodetitle.match(title)
                return episode
            end
        }
        return result
    end
  
  def find_first_unwatched_episode(tvshowid)
    puts "[#{@appname}] Looking up first unwatched episode (API version #{$apiVersion["version"]})"
    result = ""
	if ($apiVersion["version"] == 2)
      episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :fields => ["title", "showtitle", "season", "episode", "runtime", "playcount", "rating", "file"] } )["episodes"]
	else  
      episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :properties => ["title", "showtitle", "season", "episode", "runtime", "playcount", "rating", "file"] } )["episodes"]
    end
    episodes.each { |episode|

      if (episode["playcount"] == 0)
        return episode
      end         
    }
        return result
  end

  def find_latest_episode(tvshowid)
      puts "[#{@appname}] Looking up latest episode (API version #{$apiVersion["version"]})"
      result = ""
      if ($apiVersion["version"] == 2)
          episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :fields => ["title", "showtitle", "season", "episode", "runtime", "playcount", "rating", "file"], :sort => {:order => "descending",:method => "episode"}, :limits => {:end => 1} } )["episodes"]
      else
          episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :properties => ["title", "showtitle", "season", "episode", "runtime", "playcount", "rating", "file"], :sort => {:order => "descending",:method => "episode"}, :limits => {:end => 1} } )["episodes"]
      end
      episodes.each { |episode|
        return episode
      }
  end
    
    def find_random_episode(tvshowid)
        puts "[#{@appname}] Looking up latest episode (API version #{$apiVersion["version"]})"
        result = ""
        if ($apiVersion["version"] == 2)
            episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :fields => ["title", "showtitle", "season", "episode", "runtime", "playcount", "rating", "file"], :sort => {:order => "descending",:method => "random"}, :limits => {:end => 1} } )["episodes"]
            else
            episodes = xbmc('VideoLibrary.GetEpisodes', { :tvshowid => tvshowid, :properties => ["title", "showtitle", "season", "episode", "runtime", "playcount", "rating", "file"], :sort => {:order => "descending",:method => "random"}, :limits => {:end => 1} } )["episodes"]
        end
        episodes.each { |episode|
            return episode
        }
    end

    #curl -v -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "id": 1, "method": "VideoLibrary.GetEpisodes","params": {"tvshowid": 57, "sort": {"order": "descending","method": "episode"}, "limits": {"end":1}}}' http://xbmc:farside@172.16.1.17:8080/jsonrpc
    
    
  def play(file)
    puts "[#{@appname}] Playing file (API version #{$apiVersion["version"]})"
    begin
      if ($apiVersion["version"] == 2)
        Thread.new do
            xbmc('VideoPlaylist.Clear')
            xbmc('VideoPlaylist.Add', file)
            xbmc('VideoPlaylist.Play')
        end
      else
        Thread.new do 
            playItem = Hash[:file => file]
            xbmc('Player.Open', { :item => playItem })
        end
      end
    rescue
      puts "[#{@appname}] An error occurred: #{$!}"
    end
  end


  def stop()
    player = get_media_player()
    if (player != "")
      if ($apiVersion["version"] == 2)
        xbmc('VideoPlayer.Stop')
        return true
      else
        xbmc('Player.Stop', { :playerid => player })
        return true
      end
    end
    return false
  end

  def pause()
    player = get_media_player()
    if (player != "")
      if ($apiVersion["version"] == 2)
        xbmc('VideoPlayer.PlayPause')
        return true
      else
        xbmc('Player.PlayPause', { :playerid => player })
        return true
      end
    end
    return false
  end

  def scan()
    if ($apiVersion["version"] == 2)
      xbmc('VideoLibrary.ScanForContent')
    else
      xbmc('VideoLibrary.Scan')
    end
    return true
  end
    
  def clean_VideoLibrary()
    xbmc('VideoLibrary.Clean')
    return true
  end
    
  def clean_AudioLibrary()
    xbmc('AudioLibrary.Clean')
    return true
  end
  
  def open_netflix()
      xbmc('GUI.ActivateWindow', { :window => "videos", :parameters => [ 'upnp://3e81374c-009b-4a26-85f9-7a2eb96c498b/netflix//' ] })
      return true
  end

  def open_hulu()
    xbmc('GUI.ActivateWindow', { :window => "videos", :parameters => [ 'upnp://3e81374c-009b-4a26-85f9-7a2eb96c498b/hulu//' ] })
    return true
  end

  def open_plex()
    xbmc('GUI.ActivateWindow', { :window => "videos", :parameters => [ 'plugin://plugin.video.plexbmc/?content_type=video' ] })
    return true
  end
  
  def open_weather()
    xbmc('GUI.ActivateWindow', { :window => "weather" })
    return true
  end

  def open_home()
    xbmc('GUI.ActivateWindow', { :window => "home" })
    return true
  end

  def xbmc_search(searchPhrase,subject)
      #searchPhrase = searchPhrase.downcase.gsub(/ /, '+')
      #puts searchPhrase
      #json = JSON.parse(open("http://imdbapi.org?q=#{searchPhrase}") { |x| x.read }).first
      #puts json
      #searchPhrase = searchPhrase.downcase.gsub(/[^0-9A-Za-z]/, '')
      if (subject == "all")
          xbmc('Addons.ExecuteAddon', { :addonid => "script.globalsearch", :params => ["search=#{searchPhrase}&movies=true&tvshows=true&episodes=true&musicvideos=true&artists=true&albums=true&songs=true"] })
      elsif (subject == "movie")
          xbmc('Addons.ExecuteAddon', { :addonid => "script.globalsearch", :params => ["search=^alt^#{searchPhrase}&movies=true&tvshows=false&episodes=false&musicvideos=false&artists=false&albums=false&songs=false"] })
      elsif (subject == "tvshows")
          xbmc('Addons.ExecuteAddon', { :addonid => "script.globalsearch", :params => ["search=^alt^#{searchPhrase}&movies=fals&tvshows=true&episodes=false&musicvideos=false&artists=false&albums=false&songs=false"] })
      elsif (subject == "tvepisodes")
          xbmc('Addons.ExecuteAddon', { :addonid => "script.globalsearch", :params => ["search=^alt^#{searchPhrase}&movies=fals&tvshows=false&episodes=true&musicvideos=false&artists=false&albums=false&songs=false"] })
      end
      return true
  end

  def xbmc_close()
      xbmc('Input.ExecuteAction', [ "close" ])
      return true
  end

  def get_recently_added_episodes()
      xbmc('GUI.ActivateWindow', { :window => "videos", :parameters => [ 'videodb://5/' ] })
    return xbmc('VideoLibrary.GetRecentlyAddedEpisodes')
  end

  def get_recently_added_movies()
      xbmc('GUI.ActivateWindow', { :window => "videos", :parameters => [ 'videodb://4/' ] })
    return xbmc('VideoLibrary.GetRecentlyAddedMovies')
  end

  def get_tv_shows()
    return xbmc('VideoLibrary.GetTVShows')
  end

  def get_episode(id)
    return xbmc('VideoLibrary.GetEpisodeDetails', { :episodeid => id, :properties => ['tvshowid'] })
  end
end

