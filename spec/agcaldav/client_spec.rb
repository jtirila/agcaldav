# encoding: UTF-8
require 'spec_helper'
require 'fakeweb'

require 'agcaldav'

describe AgCalDAV::Client do

  before(:each) do
    @c = AgCalDAV::Client.new(:uri => "http://localhost:5232/user/calendar", :user => "user" , :password => "")
  end

  before(:all) do
    class UUID
      def generate
        "360232b0-371c-0130-9e6b-001999638933"
      end
    end
  end


  it "check Class of new calendar" do
    @c.class.to_s.should == "AgCalDAV::Client"
  end

  it "create one event" do
    uid = UUID.new.generate
    FakeWeb.register_uri(:any, %r{http://user@localhost:5232/user/calendar/(.*).ics}, [{:body => "", :status => ["200", "OK"]},
     {:body => "BEGIN:VCALENDAR\nPRODID:-//Radicale//NONSGML Radicale Server//EN\nVERSION:2.0\nBEGIN:VEVENT\nDESCRIPTION:12345 12ss345\nDTEND:20130101T110000\nDTSTAMP:20130101T161708\nDTSTART:20130101T100000\nSEQUENCE:0\nSUMMARY:123ss45\nUID:#{uid}\nX-RADICALE-NAME:#{uid}.ics\nEND:VEVENT\nEND:VCALENDAR",  :status => ["200", "OK"]}])
    r = @c.create_event({:start => "2012-12-29 10:00", :end => "2012-12-30 12:00", :title => "12345", :description => "12345 12345"}, false)
    r.should_not be_nil
  end

  it "delete one events" do
    uid = UUID.new.generate
    FakeWeb.register_uri(:delete, %r{http://user@localhost:5232/user/calendar/(.*).ics}, [{:body => "1 deleted.", :status => ["200", "OK"]}, {:body => "not found",  :status => ["404", "Not Found"]}])
    r = @c.delete_event(uid)
    r.should == true
    # second time false
    r = @c.delete_event(uid)
    r.should == false    
  end  


  it "failed create one event DuplicateError" do
    uid = "5385e2d0-3707-0130-9e49-0019996389cc"
    FakeWeb.register_uri(:any, %r{http://user@localhost:5232/user/calendar/(.*).ics}, :body => "BEGIN:VCALENDAR\nPRODID:.....")
    lambda{@c.create_event(:start => "2012-12-29 10:00", :end => "2012-12-30 12:00", :title => "12345", :description => "12345 12345")}.should raise_error(AgCalDAV::DuplicateError) 
  end


  it "update one event" do 
   # same as delete && create
   #TODO  
  end  
 
  it "find one event" do
    uid = "5385e2d0-3707-0130-9e49-001999638982"
    FakeWeb.register_uri(:get, "http://user@localhost:5232/user/calendar/#{uid}.ics", :body => "BEGIN:VCALENDAR\nPRODID:-//Radicale//NONSGML Radicale Server//EN\nVERSION:2.0\nBEGIN:VEVENT\nDESCRIPTION:12345 12ss345\nDTEND:20130101T110000\nDTSTAMP:20130101T161708\nDTSTART:20130101T100000\nSEQUENCE:0\nSUMMARY:123ss45\nUID:#{uid}\nX-RADICALE-NAME:#{uid}.ics\nEND:VEVENT\nEND:VCALENDAR")
     r = @c.find_event(uid)
     r.should_not be_nil
     r.uid.should == uid
  end


  it "find 2 events" do
    module Net
      # Fakeweb doesn't worke here HTTP-method "REPORT" is unknown 
      class HTTP
        def request(req, body = nil, &block)
          self
        end
        def code
          "200"
        end
        def body
          "<?xml version=\"1.0\"?>\n<multistatus xmlns=\"DAV:\" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">\n  <response>\n    <href>/user/calendar/960232b0-371c-0130-9e6b-001999638982.ics</href>\n    <propstat>\n      <prop>\n        <getetag>\"-5984324385549365166\"</getetag>\n        <C:calendar-data>BEGIN:VCALENDAR\nPRODID:-//Radicale//NONSGML Radicale Server//EN\nVERSION:2.0\nBEGIN:VEVENT\nDESCRIPTION:12345 12345\nDTEND:20010202T120000\nDTSTAMP:20130102T161119\nDTSTART:20010202T080000\nSEQUENCE:0\nSUMMARY:6789\nUID:960232b0-371c-0130-9e6b-001999638982\nX-RADICALE-NAME:960232b0-371c-0130-9e6b-001999638982.ics\nEND:VEVENT\nEND:VCALENDAR\n</C:calendar-data>\n      </prop>\n      <status>HTTP/1.1 200 OK</status>\n    </propstat>\n  </response>\n  <response>\n    <href>/user/calendar/98f067a0-371c-0130-9e6c-001999638982.ics</href>\n    <propstat>\n      <prop>\n        <getetag>\"3611068816283260390\"</getetag>\n        <C:calendar-data>BEGIN:VCALENDAR\nPRODID:-//Radicale//NONSGML Radicale Server//EN\nVERSION:2.0\nBEGIN:VEVENT\nDESCRIPTION:12345 12345\nDTEND:20010203T120000\nDTSTAMP:20130102T161124\nDTSTART:20010203T080000\nSEQUENCE:0\nSUMMARY:6789\nUID:98f067a0-371c-0130-9e6c-001999638982\nX-RADICALE-NAME:98f067a0-371c-0130-9e6c-001999638982.ics\nEND:VEVENT\nEND:VCALENDAR\n</C:calendar-data>\n      </prop>\n      <status>HTTP/1.1 200 OK</status>\n    </propstat>\n  </response>\n</multistatus>\n\n"          
        end
      end
    end
     r = @c.find_events(:start => "2001-02-02 07:00", :end => "2000-02-03 23:59")
     r.should_not be_nil
     r.length.should == 2
   end



end
