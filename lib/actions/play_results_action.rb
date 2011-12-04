require_relative 'reply_action'

#
# 
# 
class PlayResultsAction
  include ReplyAction
  
  PLAY_REGEX = /^(?:play)?\s?(?:result)?\s?((?:\d[\s,-]*)+|all)$/
  
  #
  # @param [Proc] reply the proc that can be called with a message
  # @param [Proc] queue the proc that can be called with the songs to be queued
  # @param [Enumerable] search_results object that is a reference to the 
  #   search results
  # 
  # @note when assigning the search results object here, ensure the other 
  #  instance is not replaced and is instead maintained and updated or the 
  #  connection with the queue will be lost.
  #
  def initialize(reply,queue,search_results)
    @reply = reply
    @search_results = search_results
    @queue = queue
  end
  
  def match?(request)
    request =~ PLAY_REGEX
  end
  
  def examples
    [ "play <index> - queues song in the search results at index <index>",
      "play all - queues all songs in the search results" ]
  end

  def handle(time,sender,message)

    # 
    # Determine the tracks requested from the user's play request
    # 
    requested_tracks = parse_tracks_to_play(message)
    
    #
    # Determine the search results to use to match against the requested tracks
    # 
    results = results_for(sender,time)
    
    # If there are no results to compare the requested tracks to, then inform
    # the user of that and stop the action
    
    if results.nil? or results.empty?
      reply "I don't have any search results"
      return
    end
    
    #
    # Queue all the songs when the request is 'all' or the individually
    # assigned requests.
    #
    
    if requested_tracks.first == "all"
      queue results.results
    else
      queue requested_tracks.map {|request| results[request] }.compact
    end
    
  end
  
  #
  # @param [String] sender the result set for the specified sender.
  # @param [Time] time the time of this request to use to find out if the 
  #   results are too old to be used.
  # 
  # @return [SearchResult] the results for the sender if present and not
  #   too old; defaults to the last result set for any user.
  
  def results_for(sender,time)
    results_for_sender = @search_results[sender]
    
    if results_for_sender and results_for_sender.are_not_old?(time)
      results_for_sender
    else
      @search_results["LAST_RESULSET"]
    end
  end
  
  #
  # @param [Array,String] track_request the play request that is going to be 
  #   parsed for available tracks.
  # 
  # @return [Array] track numbers that were identified.
  # 
  def parse_tracks_to_play(track_request)
    if Array(track_request).join(' ') =~ /play all/
      [ 'all' ]
    else
      Array(track_request).join(' ')[PLAY_REGEX,-1].to_s.split(/(?:\s|,\s?)/).map do |track| 
        tracks = track.split("-")
        (tracks.first.to_i..tracks.last.to_i).to_a
      end.flatten.uniq.compact
    end
  end
  
  
  def queue(tracks)
    @queue.call(tracks)
  end
  
  
end