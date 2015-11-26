=begin
  Copyright (C) 2005 Jeff Rose

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end
module Icalendar
  # A Todo calendar component is a grouping of component
  # properties and possibly Alarm calendar components that represent
  # an action-item or assignment. For example, it can be used to
  # represent an item of work assigned to an individual; such as "turn in
  # travel expense today".
  class Todo < Component
    component :alarms

    # Single properties
    single_property :ip_class, :text
    single_property :completed, :boolean
    single_property :created, :datetime
    single_property :description, :text
    single_property :dtstamp, :datetime
    single_property :dtstart, :datetime
    single_property :geo, :text
    single_property :last_modified, :datetime
    single_property :location, :text
    single_property :organizer, :text
    single_property :percent_complete, :integer
    single_property :priority, :integer
    single_property :recurid, :integer
    single_property :sequence, :integer
    single_property :status, :text
    single_property :summary, :text
    single_property :uid, :text
    single_property :url, :url
    
    # Single but mutually exclusive TODO: not testing anything yet
    single_property :due, :datetime
    single_property :duration, :integer

    # Multi-properties
    multi_property :attach, :text 
    multi_property :attendee, :text 
    multi_property :categories, :text 
    multi_property :comment, :text 
    multi_property :contact, :text 
    multi_property :exdate, :datetime 
    multi_property :exrule, :text
    multi_property :rstatus, :text 
    multi_property :related_to, :text
    multi_property :resources, :text
    multi_property :rdate, :datetime
    multi_property :rrule, :recur
    
    def initialize()
      super("VTODO")

      sequence 0
      timestamp DateTime.now
    end

  end
end
