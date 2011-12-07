require_relative 'reply_action'
require_relative '../rdio_results_formatter'

class Robut::Plugin::Rdio::ShowResultsAction
  include Robut::Plugin::Rdio::ReplyAction

  def initialize(reply,search_results)
    @reply = reply
    @search_results = search_results
  end

  def examples
    "show results"
  end
  
  def match?(message)
    message =~ /^show(?: me)?(?: all)? results$/
  end
  
  def handle(time,sender,message)
    
    search_results = @search_results.results_for sender, time
    
    reply "@#{sender.split(' ').first} I found the following:\n#{format_results_for_queueing(search_results.results)}"
    
  end

  #
  # Formats the results for the purposes of displaying back to the user in an
  # ordered list with prefix index to allow the user an easy way to later enqueue
  # the tracks for playing.
  # 
  # @param [Result,Results] results a result or results that you want to display
  #   with prefixed indexes.
  #
  def format_results_for_queueing(results,starting_index=0)
    Array(results).each_with_index.map do |result, index|
      "#{starting_index + index}: #{format_result(result)}"
    end.join("\n")
  end

  #
  # @param [Result] search_result an Rdio object that will be displayed
  #
  def format_result(search_result)
    Robut::Plugin::Rdio::RdioResultsFormatter.format_result search_result
  end
  
end