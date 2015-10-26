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
      http
    end

    def find_events data
      events = []
      res = nil
      __create_http.start {|http|
      	
        req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml'} )
        
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
      }
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
      __create_http.start {|http|
        address = "#{@url}/#{uuid}.ics"
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('GET')
        end
        res = http.request( req )
      }
      errorhandling res
      begin
      	r = Icalendar.parse(res.body)
      rescue
      	return false
      else
      	r.first.events.first
      end

      
    end

    def delete_event uuid
      res = nil
      __create_http.start {|http|
        req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('DELETE')
        end
        res = http.request( req )
      }
      errorhandling res
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


    def event_from_hash(hsh, checkduplicate)
      c = Calendar.new
      event_start = hsh[:start].to_datetime
      event_end = hsh[:end].to_datetime
      tzid = Time.zone.name
      tz = TZInfo::Timezone.get(tzid)
      timezone = tz.ical_timezone event_start
      c.add timezone
      c.events = []
      uuid = hsh[:uid] || UUID.new.generate
      if checkduplicate
        raise DuplicateError if entry_with_uuid_exists?(uuid)
      end

      c.event do
        uid           uuid
        dtstart       event_start.tap { |d| d.ical_params = {'TZID' => tzid} }
        dtend         event_end
        categories    hsh[:categories]# Array
        contacts      hsh[:contacts] # Array
        attendees     hsh[:attendees]# Array
        duration      hsh[:duration]
        summary       hsh[:title]
        description   hsh[:description]
        klass         hsh[:accessibility] #PUBLIC, PRIVATE, CONFIDENTIAL
        location      hsh[:location]
        geo_location  hsh[:geo_location]
        status        hsh[:status]
        url           hsh[:url]
      end
      c
    end

    # FIXME: currently unused
    def event_from_ical_event(ical_event)
      c = Calendar.new
      c.events = []
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
      e = event_from_hash(event, checkduplicate)
      cstring = e.to_ical
      res = nil
      http = Net::HTTP.new(@host, @port)
      __create_http.start { |http|
        req = Net::HTTP::Put.new("#{@url}/#{e.events.first.uid}.ics")
        req['Content-Type'] = 'text/calendar'
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('PATCH')
        end
        req.body = cstring
        res = http.request( req )
      }
      errorhandling res
      find_event e.events.first.uid
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
      __create_http.start {|http|
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('GET')
        end
        res = http.request( req )
      }  
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
      http = Net::HTTP.new(@host, @port)
      __create_http.start { |http|
        req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
        req['Content-Type'] = 'text/calendar'
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('PUT')
        end
        req.body = cstring
        res = http.request( req )
      }
      errorhandling res
      find_todo uuid
    end

    def create_todo
      res = nil
      raise DuplicateError if entry_with_uuid_exists?(uuid)

      __create_http.start {|http|
        req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml'} )
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('REPORT')
        end
        req.body = AgCalDAV::Request::ReportVTODO.new.to_xml
        res = http.request( req )
      }
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
      
      __create_http.start {|http|
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if not @authtype == 'digest'
        	req.basic_auth @user, @password
        else
        	req.add_field 'Authorization', digestauth('GET')
        end
        
        res = http.request( req )
      	
      }
      begin
        errorhandling res
      	Icalendar.parse(res.body)
      rescue
      	return false
      else
      	return true
      end
    end
    def  errorhandling response
      raise AuthenticationError if response.code.to_i == 401
      raise NotExistError if response.code.to_i == 410 
      raise APIError if response.code.to_i >= 500
    end
  end


  class AgCalDAVError < StandardError
  end
  class AuthenticationError < AgCalDAVError; end
  class DuplicateError      < AgCalDAVError; end
  class APIError            < AgCalDAVError; end
  class NotExistError       < AgCalDAVError; end
end
