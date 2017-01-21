require 'active_support/core_ext/string/conversions'
require 'tzinfo'
require 'icalendar'
require_relative './datetime'
require 'icalendar/calendar'
require 'icalendar/tzinfo'

module AgCalDAV
  class Client
    include Icalendar
    attr_accessor :host, :port, :url, :user, :password, :ssl

    def format=( fmt )
      @format = fmt
    end

    def format
      @format ||= Format::Debug.new
    end

    def initialize( data )
      unless data[:proxy_uri].nil?
        proxy_uri   = URI(data[:proxy_uri])
        @proxy_host = proxy_uri.host
        @proxy_port = proxy_uri.port.to_i
      end

      uri = URI(data[:uri])
      @host     = uri.host
      @port     = uri.port.to_i
      @url      = uri.path
      @user     = data[:user]
      @open_timeout  = data[:open_timeout]
      @read_timeout  = data[:read_timeout]
      @password = data[:password]
      @ssl      = uri.scheme == 'https'

      unless data[:authtype].nil?
      	@authtype = data[:authtype]
      	if @authtype == 'digest'

      		@digest_auth = Net::HTTP::DigestAuth.new
      		@duri = URI.parse data[:uri]
      		@duri.user = @user
      		@duri.password = @password

      	elsif @authtype == 'basic'
	    	#Don't Raise or do anything else
	    else
	    	raise "Authentication Type Specified Is Not Valid. Please use basic or digest"
	    end
      else
      	@authtype = 'basic'
      end
    end

    def __create_http
      if @proxy_uri.nil?
        http = Net::HTTP.new(@host, @port)
      else
        http = Net::HTTP.new(@host, @port, @proxy_host, @proxy_port)
      end
      if @ssl
        http.use_ssl = @ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http
    end

    def find_events data
      events = []
      res = nil
      __create_http.start do |http|

        req = Net::HTTP::Report.new(@url, {'Content-Type'=>'application/xml; charset="utf-8"', 'Depth'=>'1'} )

        if not @authtype == 'digest'
          req.basic_auth @user, @password
        else
          req.add_field 'Authorization', digestauth('REPORT')
        end

		    if data[:start].is_a? Integer
          req.body = AgCalDAV::Request::ReportVEVENT.new(Time.at(data[:start]).utc.strftime("%Y%m%dT%H%M%S"),
                                                        Time.at(data[:end]).utc.strftime("%Y%m%dT%H%M%S") ).to_xml
        else
          req.body = AgCalDAV::Request::ReportVEVENT.new(DateTime.parse(data[:start]).utc.strftime("%Y%m%dT%H%M%S"),
                                                        DateTime.parse(data[:end]).utc.strftime("%Y%m%dT%H%M%S") ).to_xml
        end
        res = http.request(req)
      end
      errorhandling res

      result = ""

      xml = REXML::Document.new(res.body)
      REXML::XPath.each( xml, '//c:calendar-data/', {"c"=>"urn:ietf:params:xml:ns:caldav"} ){|c| result << c.text}
      r = Icalendar.parse(result)
      unless r.empty?
        r.each do |calendar|
          calendar.events.each do |event|
            events << event
          end
        end
        events
      else
        return false
      end
    end

    def find_event uuid
      res = nil
      __create_http.start do |http|
        address = "#{@url}/#{uuid}.ics"
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('GET')
        end
        res = http.request( req )
      end
      errorhandling res
      begin
      	r = Icalendar.parse(res.body)
      rescue
      	return false
      else
      	r.try(:first).try(:events).try(:first)
      end


    end

    def delete_event uuid
      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('DELETE')
        end
        res = http.request( req )
      end
      errorhandling res rescue NotExistError
      # accept any success code
      if res.code.to_i.between?(200,299)
        return true
      else
        return false
      end
    end

    def hash_from_event(event)
      {
        :uid => event.uid,
        :start => event.dtstart.strftime("%Y-%m-%d %H:%M:%S"),
        :end => event.dtstart.strftime("%Y-%m-%d %H:%M:%S"),
        :title => event.summary,
        :description => event.description,
        :categories => event.categories
      }
    end


    def calendar_from_event(event, checkduplicate)
      c = Icalendar::Calendar.new
      if event.is_a? Hash
        event_start = Icalendar::Values::DateTime.new(event[:start].to_datetime)
        tzid_for_lookup = Time.zone.try(:name) || "UTC"
        tz = ActiveSupport::TimeZone.find_tzinfo(tzid_for_lookup)
        tzid = tz.try(:name)
        timezone = tz.ical_timezone(event_start)
        c.add_component timezone
        event_end = Icalendar::Values::DateTime.new(event[:end].to_datetime)
        uuid = event[:uid] || UUID.new.generate
        if checkduplicate
          raise DuplicateError if entry_with_uuid_exists?(uuid)
        end
        ical_event = Icalendar::Event.new
        ical_event.uid          = uuid
        ical_event.dtstart      = event_start.tap { |d| d.icalendar_tzid = tzid; d.ical_params = {'TZID' => [tzid]}}
        ical_event.dtend        = event_end.tap { |d| d.icalendar_tzid = tzid; d.ical_params = {'TZID' => [tzid]}}
        ical_event.dtstamp      = Icalendar::Values::DateTime.new(Time.now.to_datetime.utc)
        ical_event.categories   = event[:categories]# Array
        ical_event.contacts     = event[:contacts] # Array
        ical_event.attendees    = event[:attendees]# Array
        ical_event.duration     = event[:duration]
        ical_event.summary      = event[:title]
        ical_event.description  = event[:description]
        ical_event.ip_class     = event[:accessibility] #PUBLIC, PRIVATE, CONFIDENTIAL
        ical_event.location     = event[:location]
        ical_event.geo          = event[:geo_location]
        ical_event.status       = event[:status]
        ical_event.url          = event[:url]
        c.add_event(ical_event)
      elsif !event.is_a?(Icalendar::Event)
        raise InvalidEventDataError
      else
        tzid = Time.zone.try(:name) || "UTC"
        tz = ActiveSupport::TimeZone.find_tzinfo(tzid)
        timezone = tz.ical_timezone(event_start)
        c.add_component timezone
        uuid = event.uid
        if checkduplicate
          raise DuplicateError if entry_with_uuid_exists?(uuid)
        end
        c.add_event(event)
      end
      c
    end

    # FIXME: currently unused
    def event_from_ical_event(ical_event)
      c = Calendar.new
      start_time = ical_event.dtstart.dup
      end_time = ical_event.dtend.dup
      start_time.icalendar_tzid = start_time.icalendar_tzid.gsub("\0", "")
      end_time.icalendar_tzid = end_time.icalendar_tzid.gsub("\0", "")
      c.event do
        uid           ical_event.uid
        dtstart       start_time
        dtend         end_time
        categories    ical_event.categories
        contacts      ical_event.contacts # Array
        attendees     ical_event.attendees # Array
        duration      ical_event.duration
        summary       ical_event.summary.gsub("\"", "")
        description   ical_event.description.gsub("\"", "")
        klass         ical_event.klass.gsub("\"", "")
        location      ical_event.location
        geo_location  ical_event.geo_location
        status        ical_event.status
        url           ical_event.url
      end
      c
    end

    def create_event(event, checkduplicate = true)
      return unless c = calendar_from_event(event, checkduplicate)

      cstring = c.to_ical

      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Put.new("#{@url}/#{c.events.first.uid}.ics")
        req['Content-Type'] = 'text/calendar'
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('PATCH')
        end
        req.body = cstring
        res = http.request( req )
      end
      errorhandling res
      find_event c.events.first.uid
    end

    def update_event event
      #TODO... fix me
      if delete_event event[:uid]
        create_event(hash_from_event(event), false)
      else
        return false
      end
    end

    def add_alarm tevent, altCal="Calendar"

    end

    def find_todo uuid
      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('GET')
        end
        res = http.request( req )
      end
      errorhandling res
      r = Icalendar.parse(res.body)
      r.first.todos.first
    end





    def create_todo todo
      c = Calendar.new
      uuid = UUID.new.generate
      raise DuplicateError if entry_with_uuid_exists?(uuid)
      c.todo do
        uid           uuid
        start         DateTime.parse(todo[:start])
        duration      todo[:duration]
        summary       todo[:title]
        description   todo[:description]
        klass         todo[:accessibility] #PUBLIC, PRIVATE, CONFIDENTIAL
        location      todo[:location]
        percent       todo[:percent]
        priority      todo[:priority]
        url           todo[:url]
        geo           todo[:geo_location]
        status        todo[:status]
      end
      c.todo.uid = uuid
      cstring = c.to_ical
      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
        req['Content-Type'] = 'text/calendar'
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('PUT')
        end
        req.body = cstring
        res = http.request( req )
      end
      errorhandling res
      find_todo uuid
    end

    def create_todo
      res = nil
      raise DuplicateError if entry_with_uuid_exists?(uuid)

      __create_http.start do |http|
        req = Net::HTTP::Report.new(@url, {'Content-Type'=>'application/xml; charset="utf-8"', 'Depth'=>'1'} )
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('REPORT')
        end
        req.body = AgCalDAV::Request::ReportVTODO.new.to_xml
        res = http.request( req )
      end
      errorhandling res
      format.parse_todo( res.body )
    end

    private

    def digestauth method

	    h = Net::HTTP.new @duri.host, @duri.port
	    if @ssl
	    	h.use_ssl = @ssl
	    	h.verify_mode = OpenSSL::SSL::VERIFY_NONE
	    end
	    req = Net::HTTP::Get.new @duri.request_uri

	    res = h.request req
	    # res is a 401 response with a WWW-Authenticate header

	    auth = @digest_auth.auth_header @duri, res['www-authenticate'], method

    	return auth
    end

    def entry_with_uuid_exists? uuid
      res = nil

      __create_http.start do |http|
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('GET')
        end

        res = http.request( req )


      end
      begin
        errorhandling res
        Icalendar.parse(res.body)
      rescue
      	return false
      else
      	return true
      end
    end

    def errorhandling response
      raise AuthenticationError if response.try(:code).try(:to_i) == 401
      raise NotExistError if response.try(:code).try(:to_i) == 410
      raise NotExistError if response.try(:code).try(:to_i) == 404
      raise APIError if response.try(:code).try(:to_i).try(:>=, 500)
    end
  end


  class AgCalDAVError < StandardError
  end
  class AuthenticationError    < AgCalDAVError; end
  class DuplicateError         < AgCalDAVError; end
  class APIError               < AgCalDAVError; end
  class NotExistError          < AgCalDAVError; end
  class InvalidEventDataError < AgCalDAVError; end
end
