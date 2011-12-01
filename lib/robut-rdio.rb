require 'robut'
require_relative 'server/server'
require 'rdio'

# A plugin that hooks into Rdio, allowing you to queue songs from
# HipChat. +key+ and +secret+ must be set before we can deal with any
# Rdio commands. Additionally, you must call +start_server+ in your
# Chatfile to start the Rdio web server.
class Robut::Plugin::Rdio
  include Robut::Plugin

  class << self
    # Your Rdio API Key
    attr_accessor :key

    # Your Rdio API app secret
    attr_accessor :secret

    # The port the Rdio web player will run on. Defaults to 4567.
    attr_accessor :port

    # The host the Rdio web player will run on. Defaults to localhost.
    attr_accessor :host

    # The playback token for +domain+. If you're accessing Rdio on
    # localhost, you shouldn't need to change this. Otherwise,
    # download the rdio-python plugin:
    #
    #   https://github.com/rdio/rdio-python
    #
    # and generate a new token for your domain:
    #
    #   ./rdio-call --consumer-key=YOUR_CONSUMER_KEY --consumer-secret=YOUR_CONSUMER_SECRET getPlaybackToken domain=YOUR_DOMAIN
    attr_accessor :token

    # The domain associated with +token+. Defaults to localhost.
    attr_accessor :domain
  end

  # Starts a Robut::Plugin::Rdio::Server server for communicating with
  # the actual Rdio web player. You must call this in the Chatfile if
  # you plan on using this gem.
  def self.start_server
    @server = Thread.new { Server.run! :host => (host || "localhost"), :port => (port || 4567) }
    Server.token = self.token || "GAlNi78J_____zlyYWs5ZG02N2pkaHlhcWsyOWJtYjkyN2xvY2FsaG9zdEbwl7EHvbylWSWFWYMZwfc="
    Server.domain = self.domain || "localhost"
  end

  # Returns a description of how to use this plugin
  def usage
    [
      "#{at_nick} play <song> - queues <song> for playing",
      "#{at_nick} play album <album> - queues <album> for playing",
      "#{at_nick} play track <track> - queues <track> for playing",
      "#{at_nick} play/unpause - unpauses the track that is currently playing",
      "#{at_nick} next - move to the next track",
      "#{at_nick} next|skip album - skip all tracks in the current album group",
      "#{at_nick} restart - restart the current track"
    ]
  end
 
  #
  # @param [String,Array] request that is being evaluated as a play request
  # @return [Boolean]
  #
  def play?(request)
    Array(request).join(' ') =~ /^(play)?\s?(result)?\s?\d/
  end

  #
  # @return [Regex] that is used to match searches for their parameters
  # @see http://rubular.com/?regex=(find%7Cdo%20you%20have(%5Csany)%3F)%5Cs%3F(.%2B%5B%5E%3F%5D)%5C%3F%3F
  # 
  def search_regex
    /(find|do you have(\sany)?)\s?(.+[^?])\??/
  end
  
  #
  # @param [String,Array] request that is being evaluated as a search request
  # @return [Boolean]
  #
  def search?(request)
    Array(request).join(' ') =~ search_regex
  end

  #
  # @param [String,Array] request that is being evaluated as a search and playback 
  #   request
  # @return [Boolean]
  #
  def search_and_play?(request)
    Array(request).join(' ') =~ /^play\b[^\b]+/
  end

  #
  # @param [String,Array] request that is being evaluated as a playback request
  # @return [Boolean]
  #
  def playback?(request)
    Array(request).join(' ') =~ /^(?:play|(?:un)?pause|next|restart|back|clear|(?:next|skip) album)$/
  end

  #
  # @param [String,Array] request that is being evaluated as a skip album request
  # @return [Boolean]
  #
  def skip_album?(message)
    message =~ /(next|skip) album/
  end
  
  # Queues songs into the Rdio web player. @nick play search query
  # will queue the first search result matching 'search query' into
  # the web player. It can be an artist, album, or song.
  def handle(time, sender_nick, message)
    
    Server.reply_callback ||= lambda{|message| reply(message, :room)}
    Server.state_callback ||= lambda{|message| reply("/me #{message}", :room)}
    
    ::Rdio.init(self.class.key, self.class.secret)
    words = words(message)
    
    if sent_to_me?(message)
      
      if play?(words)
        
        play_result(words.last.to_i)
        
      elsif search_and_play?(words)
        
        results = search(message)
        result = results.first
        if result
          queue(result)
        else
          reply("I couldn't find #{words.join(" ")} on Rdio.")
        end
        
      elsif search?(words)
        
        find words.join(' ')[search_regex,-1]
      
      elsif skip_album?(message)

        run_command("next_album")

      else playback?(words)
        
        run_command(words.join("_"))
        
      end
      
    end
    
  end

  def results
    @@results
  end

  private
  RESULT_DISPLAYER = {
    ::Rdio::Album => lambda{|album| "#{album.artist.name} - #{album.name}"},
    ::Rdio::Track => lambda{|track| "#{track.artist.name} - #{track.album.name} - #{track.name}"}
  }

  def run_command(command)
    Server.command << command
  end

  def find(query)
    reply("Searching for: #{query}...")
    @@results = search(query)

    result_display = format_results(@@results)
    reply(result_display)
  end

  def format_results(results)
    result_display = ""
    results.each_with_index do |result, index|
      result_display += format_result(result, index) + "\n"
    end
    result_display
  end

  def play_result(number)
    if !has_results?
      reply("I don't have any search results") and return
    end

    if !has_result?(number)
      reply("I don't have that result") and return
    end

    queue result_at(number)
  end

  def has_results?
    @@results && @@results.any?
  end

  def has_result?(number)
    !@@results[number].nil?
  end

  def result_at(number)
    @@results[number]
  end

  def queue(result)
    Server.queue << result.key
    name = result.name
    name = "#{result.artist_name} - #{name}" if result.respond_to?(:artist_name) && result.artist_name
    reply("Queuing: #{name}")
  end


  def format_result(search_result, index)
    response = RESULT_DISPLAYER[search_result.class].call(search_result)
    puts response
    "#{index}: #{response}"
  end

  # Searches Rdio for sources matching +words+. 
  # 
  # Given an array of Strings, which are the search terms, use Rdio to find any
  # tracks that match. If the first word happens be `album` then search for
  # albums that match the criteria.
  #
  #
  def search(words)
    api = ::Rdio::Api.new(self.class.key, self.class.secret)
    words = words.split(' ')
    
    if words.first == "album"
      query_string = words[1..-1].join(' ')
      results = api.search(query_string, "Album")
    elsif words.first == "track"
      query_string = words[1..-1].join(' ')
      results = api.search(query_string, "Track")
    elsif words.first == "artist"
      query_string = words[1..-1].join(' ')
      results = api.search(query_string, "Artist")
   else
      query_string = words.join(' ')
      results = api.search(query_string, "Track")
    end
  end

end
