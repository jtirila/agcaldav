module Icalendar
  # A Event calendar component is a grouping of component
  # properties, and possibly including Alarm calendar components, that
  # represents a scheduled amount of time on a calendar. For example, it
  # can be an activity; such as a one-hour long, department meeting from
  # 8:00 AM to 9:00 AM, tomorrow. Generally, an event will take up time
  # on an individual calendar.
  class Event < Component

    ## Single instance properties

    # # Access classification (PUBLIC, PRIVATE, CONFIDENTIAL...)
    # single_property :ip_class, Icalendar::Values::Text

    # # Date & time of creation
    # single_property :created, Icalendar::Values::DateTime

    # # Complete description of the calendar component
    # single_property :description, Icalendar::Values::Text

    attr_accessor :tzid

    # # Specifies date-time when calendar component begins
    # single_property :dtstart, Icalendar::Values::DateTime

    # # Latitude & longitude for specified activity
    # single_property :geo, Icalendar::Values::Text

    # # Date & time this item was last modified
    # single_property :last_modified, Icalendar::Values::DateTime

    # # Specifies the intended venue for this activity
    # single_property :location, Icalendar::Values::Text

    # # Defines organizer of this item
    # single_property :organizer, Icalendar::Values::Text

    # # Defines relative priority for this item (1-9... 1 = best)
    # single_property :priority, Icalendar::Values::Integer

    # # Indicate date & time when this item was created
    # single_property :dtstamp, Icalendar::Values::DateTime

    # # Revision sequence number for this item
    # single_property :sequence, Icalendar::Values::Integer

    # # Defines overall status or confirmation of this item
    # single_property :status, Icalendar::Values::Text
    # single_property :summary, Icalendar::Values::Text
    # single_property :transp, Icalendar::Values::Integer

    # # Defines a persistent, globally unique id for this item
    # single_property :uid, Icalendar::Values::Text

    # # Defines a URL associated with this item
    # single_property :url, Icalendar::Values::Text
    # single_property :recurrence_id, Icalendar::Values::Integer

    # ## Single but mutually exclusive properties (Not testing though)

    # # Specifies a date and time that this item ends
    # single_property :dtend, Icalendar::Values::DateTime

    # # Specifies a positive duration time
    # single_property :duration, Icalendar::Values::Integer

    # ## Multi-instance properties

    # # Associates a URI or binary blob with this item
    # multi_property :attach, Icalendar::Values::Uri 

    # # Defines an attendee for this calendar item
    # single_property :attendee, Icalendar::Values::Text

    # # Defines the categories for a calendar component (school, work...)
    # multi_property :categories, Icalendar::Values::Text

    # # Simple comment for the calendar user.
    # multi_property :comment, Icalendar::Values::Text

    # # Contact information associated with this item.
    multi_property :contacts, Icalendar::Values::Text
    multi_property :attendees, Icalendar::Values::Text
    # multi_property :exdates, Icalendar::Values::DateTime
    # multi_property :exrule, Icalendar::Values::Recur
    # multi_property :rstatus, Icalendar::Values::Text

    # # Used to represent a relationship between two calendar items
    # multi_property :related_to, Icalendar::Event 
    # multi_property :resources, Icalendar::Event 

    # # Used with the UID & SEQUENCE to identify a specific instance of a
    # # recurring calendar item.
    # multi_property :rdate, Icalendar::Values::Date
    # multi_property :rrule, Icalendar::Values::Recur

    def initialize()
      super("event")

      # Now doing some basic initialization
      sequence=0
      dtstamp=DateTime.now
    end

    def alarm(&block)
      a = Alarm.new
      self.add a

      a.instance_eval(&block) if block

      a
    end

    def occurrences_starting(time)
      recurrence_rules.first.occurrences_of_event_starting(self, time)
    end

  end
end
