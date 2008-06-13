#MES- From C:\ruby\lib\ruby\gems\1.8\gems\activerecord-1.14.2\lib\active_record\associations\has_and_belongs_to_many_association.rb
module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
        def construct_sql
          interpolate_sql_options!(@reflection.options, :finder_sql)

          if @reflection.options[:finder_sql]
            @finder_sql = @reflection.options[:finder_sql]
          else
            @finder_sql = "#{@reflection.options[:join_table]}.#{@reflection.primary_key_name} = #{@owner.quoted_id} "
            @finder_sql << " AND (#{conditions})" if conditions
#MES- New stuff
            if @reflection.options[:dynamic_conditions]
              dyn_cond = @owner.send(@reflection.options[:dynamic_conditions])
              @finder_sql << " AND #{interpolate_sql(dyn_cond)}" if dyn_cond
            end
#MES- End of new stuff
          end

          @join_sql = "INNER JOIN #{@reflection.options[:join_table]} ON #{@reflection.klass.table_name}.#{@reflection.klass.primary_key} = #{@reflection.options[:join_table]}.#{@reflection.association_foreign_key}"
        end
        
      def update_attributes(record, join_attributes = {})
        # Did they pass in an ID or an object?
        if record.is_a? ActiveRecord::Base
          # Check the type of the passed in record
          raise_on_type_mismatch(record)

          # Find the actual record in @target, if @target is loaded
          if loaded?
            record_in_arr = @target.find { | item | item == record }
            raise ActiveRecord::RecordNotFound, "#{record.class} #{record.id} not found in collection" unless !record_in_arr.nil?

            record = record_in_arr
            record_id = record.id
          else
            record_id = record.id
            record = nil
          end
        else
          # The record isn't an ActiveRecord, assume it's an ID
          record_id = record.to_i

          # If the target is loaded, find the record in the target
          if loaded?
            # Find the actual record in @target
            record_in_arr = @target.find { | item | item.id == record_id }
            raise ActiveRecord::RecordNotFound, "Item with ID #{record_id} not found in collection" if record_in_arr.nil?

            record = record_in_arr
          else
            # Not loaded- for performance, don't load it, just do an update based on the ID
            record = nil
          end
        end

        # Break the join_attributes into columns and values for those columns
        cols_and_vals = join_attributes.to_a.transpose

        # Join the columns together with ' = ?, ', so the result for [a, b]
        # would be 'a = ?, b'  NOTE: We will have to add a trailing ' = ?'
        # in the SQL
        col_string = cols_and_vals[0].join(' = ?, ')

        #NOTE: :before_update doesn't do anything right now- this is "future proofing"
        callback(:before_update, record)

        # Do the SQL, passing in the args
        ret = @owner.connection().update(sanitize_sql(["UPDATE #{@reflection.options[:join_table]} SET #{col_string} = ? WHERE #{@reflection.primary_key_name} = #{@owner.quoted_id} AND #{@reflection.association_foreign_key} = ?", cols_and_vals[1], record_id].flatten), "Update Attributes")

        # Fix up @target, the array of items IF it's loaded
        join_attributes.each { | att, att_val | record[att] = att_val } if !record.nil?

        #NOTE: :after_update doesn't do anything right now- this is "future proofing"
        callback(:after_update, record)

        return ret
      end

      def push_or_update_attributes(record, join_attributes = {})
        #MGS- if the record hasn't been loaded yet, force it to be loaded
        # otherwise RecordNotFound won't be thrown.
        if !loaded?
          reload
        end
        begin
          update_attributes record, join_attributes
          return false
        #Did we find a row to update?  If not, do an insert
        rescue ActiveRecord::RecordNotFound
          push_with_attributes record, join_attributes
          return true
        end
      end
    end
  end
end



##MES- Check out this comment from the rails mailing listL
##---------- Forwarded message ----------
##From: Jay Levitt <jay-news@jay.fm>
##To: rails@lists.rubyonrails.org
##Date: Thu, 22 Sep 2005 07:27:53 -0400
##Subject: [Rails] Re: Re: Elegant way to filter HABTM collection dynamically?
##In article <c715e6405092122414377a9d1@mail.gmail.com>, joevandyk-
##Re5JQEeQqe8AvxtiuMwx3w@public.gmane.org says...
##> See the thread 'habtm example' that I just started that addresses this
##> problem.  Somewhat.
##
##Oo! oo!  Check out the CHANGELOG from EdgeRails:
##
##* Added support for calling constrained class methods on has_many and
##has_and_belongs_to_many collections #1764 [Tobias Luetke]
##
##   class Comment < AR:B
##     def self.search(q)
##       find(:all, :conditions => ["body = ?", q])
##     end
##   end
##
##   class Post < AR:B
##     has_many :comments
##   end
##
##   Post.find(1).comments.search('hi') # => SELECT * from comments WHERE
##post_id = 1 AND body = 'hi'
##
##
##--
##Jay Levitt                |
##Wellesley, MA             | I feel calm.  I feel ready.  I can only
##Faster: jay at jay dot fm | conclude that's because I don't have a
##http://www.jay.fm         | full grasp of the situation. - Mark Adler
#
#
#