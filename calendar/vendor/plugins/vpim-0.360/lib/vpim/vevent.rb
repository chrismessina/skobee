=begin
  Copyright (C) 2006 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

require 'vpim/dirinfo'
require 'vpim/field'
require 'vpim/rfc2425'
require 'vpim/vpim'
require 'vpim/property/base'
require 'vpim/property/common'
require 'vpim/property/priority'
require 'vpim/property/location'
require 'vpim/property/resources'
require 'vpim/property/recurrence'

module Vpim
  class Icalendar
    class Vevent


      include Vpim::Icalendar::Property::Base
      include Vpim::Icalendar::Property::Common
      include Vpim::Icalendar::Property::Priority
      include Vpim::Icalendar::Property::Location
      include Vpim::Icalendar::Property::Resources
      include Vpim::Icalendar::Property::Recurrence

      def initialize(fields) #:nodoc:
        outer, inner = Vpim.outer_inner(fields)

        @properties = Vpim::DirectoryInfo.create(outer)

        @elements = inner
        #MGS- begin custom
        @event = self
        @comp = self
        #MGS- end custom
        # See "TODO - fields" in dirinfo.rb
      end

      # TODO - derive everything from Icalendar::Component to get this kind of stuff?
      def fields #:nodoc:
        f = @properties.to_a
        last = f.pop
        f.push @elements
        f.push last
      end

      def properties #:nodoc:
        @properties
      end


      # Create a new Vevent object. All events must have a DTSTART field,
      # specify it as either a Time or a Date in +start+, it defaults to "now"
      # (is this useful?).
      #
      # If specified, +fields+ must be either an array of Field objects to
      # add, or a Hash of String names to values that will be used to build
      # Field objects. The latter is a convenient short-cut allowing the Field
      # objects to be created for you when called like:
      #
      #   Vevent.create(Date.today, 'SUMMARY' => "today's event")
      #
      # TODO - maybe events are usually created in a particular way? With a
      # start/duration or a start/end? Maybe I can make it easier. Ideally, I
      # would like to make it hard to encode an invalid Event.

#MGS- customized

      #def Vevent.create(start = Time.now, fields=[])
      #  dtstart = DirectoryInfo::Field.create('DTSTART', start)
      #  di = DirectoryInfo.create([ dtstart ], 'VEVENT')
      #
      #  Vpim::DirectoryInfo::Field.create_array(fields).each { |f| di.push_unique f }
      #
      #  new(di.to_a)
      #end

      #MGS- the other create method, wasn't too helpful as you had to pass in a START
      def Vevent.create(fields=[])
        di = DirectoryInfo.create([ ], 'VEVENT')
        Vpim::DirectoryInfo::Field.create_array(fields).each { |f| di.push_unique f }
        new(di.to_a)
      end

#MGS- end custom

      # Creates a yearly repeating event, such as for a birthday.
      def Vevent.create_yearly(date, summary)
        create(
          date,
          'SUMMARY' => summary.to_str,
          'RRULE' => 'FREQ=YEARLY'
          )
      end

      # Accept an event invitation. The +invitee+ is the Address that wishes
      # to accept the event invitation as confirmed.
      #
      # The event created is identical to this one, but
      # - without the attendees
      # - with the invitee added with a PARTSTAT of ACCEPTED
      def accept(invitee)
        # FIXME - move to Vpim::Itip.
        invitee = invitee.copy
        invitee.partstat = 'ACCEPTED'

        fields = []

        @properties.each_with_index do
          |f,i|

          # put invitee in as field[1]
          fields << invitee.encode('ATTENDEE') if i == 1

          fields << f unless f.name? 'ATTENDEE'
        end

        Vevent.new(fields)
      end

      # In iTIP, whether this event is OPAQUE or TRANSPARENT to scheduling. If
      # transparency is not explicitly set, it defaults to OPAQUE.
      def transparency
        proptoken 'TRANSP', ["OPAQUE", "TRANSPARENT"], "OPAQUE"
      end

      #MGS- custom
      # Set transparency to "OPAQUE" or "TRANSPARENT", see Vpim::Vevent#transparency.
      def transparency(token)
        set_token 'TRANSP', ["OPAQUE", "TRANSPARENT"], "OPAQUE", token
      end
      #MGS- end custom

      # The duration in seconds of a Event, Todo, or Vfreebusy component, or
      # for Alarms, the delay period prior to repeating the alarm. The
      # duration is calculated from the DTEND and DTBEGIN fields if the
      # DURATION field is not present. Durations of zero seconds are possible.
      def duration
        dur = @properties.field 'DURATION'
        dte = @properties.field 'DTEND'
        if !dur
          return nil unless dte

          b = dtstart
          e = dtend

          return (e - b).to_i
        end

        Icalendar.decode_duration(dur.value_raw)
      end

#MGS- customized; no need for a dtend reader here
      # The end time for this calendar component. For an Event, if there is no
      # end time, then nil is returned, and the event takes up no time.
      # However, the end time will be calculated from the event duration, if
      # present.
      #def dtend
      #   dte = @properties.field 'DTEND'
      #   if dte
      #     dte.to_time.first
      #   elsif duration
      #       dtstart + duration
      #   else
      #     nil
      #   end
      #end
#MGS- end custom


#MGS- removed Maker here; as it was crappy

    end
  end
end

