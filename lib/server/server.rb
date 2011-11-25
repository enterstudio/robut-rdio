require 'robut'
require 'sinatra'
require 'json'

class Robut::Plugin::Rdio
  include Robut::Plugin

  # A simple server to communicate new Rdio sources to the Web
  # Playback API. The client will update
  # Robut::Plugin::Rdio::Server.queue with any new sources, and a call
  # to /queue.json will pull those new sources as a json object.
  class Server < Sinatra::Base

    set :root, File.dirname(__FILE__)

    class << self
      # A list of items that haven't been fetched by the web playback
      # API yet.
      attr_accessor :queue

      # A command list for the player to execute
      attr_accessor :command
      
      # The playback token for +domain+. If you're accessing Rdio over
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

      # A callback set by to Robut plugin so the server can talk to it
      attr_accessor :reply_callback
      
      attr_accessor :last_played_track
    end
    self.queue = []
    self.command = []
    
    # Renders a simple Rdio web player.
    get '/' do
      File.read(File.expand_path('public/index.html', File.dirname(__FILE__)))
    end

    get '/js/vars.js' do
      content_type 'text/javascript'
      <<END
var rdio_token = '#{self.class.token}';
var rdio_domain = '#{self.class.domain}';
END
    end

    # Returns the sources that haven't been fetched yet.
    get '/queue.json' do
      queue = self.class.queue.dup
      self.class.queue = []
      queue.to_json
    end
    
    # Returns the command for the player
    get '/command.json' do
      command = self.class.command.dup
      self.class.command = []
      command.to_json
    end

    get '/now_playing/:title' do
      if self.class.reply_callback and self.track_is_not_the_same_as_last?(URI.unescape(params[:title]))
        self.class.reply_callback.call("Now playing: #{URI.unescape(params[:title])}") 
        self.class.last_played_track = URI.unescape(params[:title])
      end
    end

    def track_is_not_the_same_as_last? current_track
      self.class.last_played_track != current_track
    end


    # start the server if ruby file executed directly
    run! if app_file == $0
  end
end

