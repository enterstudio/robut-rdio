#
# A routing method has valid/invalid input. This shared example is used by
# all of ther routing methods. 
# 
shared_examples "a routing method" do
  
  context "when given valid requests" do

    it "should return a truthy value" do
      routing_method = example.metadata[:method]
      
      valid_requests.each do |request|
        subject.send(routing_method,request).should be_true, "expected the Request '#{request}' (#{request.class}) to be valid"
      end

    end
    
  end
  
  context "when given invalid requests" do
    
    it "should return a falsy value" do
      routing_method = example.metadata[:method]

      invalid_requests.each do |request|
        subject.send(routing_method,request).should be_false, "expected the Request '#{request}' (#{request.class}) to be invalid"
      end
      
    end
    
  end
  
end

shared_examples "a matching method" do

  context "when given valid messages" do

    it "should return a truthy value" do
      valid_messages.each do |message|
        subject.match?(message).should be_true, "expected the message '#{message}' (#{message.class}) to be match"
      end

    end
    
  end
  
  context "when given invalid messages" do
    
    it "should return a falsy value" do
      invalid_messages.each do |message|
        subject.match?(message).should be_false, "expected the message '#{message}' (#{message.class}) to not match"
      end
      
    end
    
  end
  
end


shared_examples "a successfully routed action" do |parameters|
  
  it "should route the request to the correct action with the correct parameters" do
    
    # TODO I have forgotten how to set up an expectation without replacing the original method result
    # subject.should_receive(parameters[:route]).once
    subject.should_receive(parameters[:action]).with(*parameters[:parameters]).and_return(parameters[:returning])
    subject.handle(time,sender,message)
    
  end
  
end