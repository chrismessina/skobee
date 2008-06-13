#MES- From C:\ruby\lib\ruby\gems\1.8\gems\activerecord-1.14.2\lib\active_record\associations.rb
module ActiveRecord
  module Associations # :nodoc:
    module ClassMethods
      private
        def create_has_and_belongs_to_many_reflection(association_id, options, &extension)
          options.assert_valid_keys(
            :class_name, :table_name, :join_table, :foreign_key, :association_foreign_key, 
            :select, :conditions, :include, :order, :group, :limit, :offset,
            :finder_sql, :delete_sql, :insert_sql, :uniq, 
            :before_add, :after_add, :before_remove, :after_remove, 
            :extend,
#MES- New stuff
            :dynamic_conditions, :before_update, :after_update
#MES- End of new stuff
          )

          options[:extend] = create_extension_module(association_id, extension) if block_given?

          reflection = create_reflection(:has_and_belongs_to_many, association_id, options, self)

          reflection.options[:join_table] ||= join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(reflection.class_name))
          
          reflection
        end
        
        def add_association_callbacks(association_name, options)
#MES- New stuff
#          callbacks = %w(before_add after_add before_remove after_remove)
          callbacks = %w(before_add after_add before_remove after_remove before_update after_update)
#MES- End of new stuff
          callbacks.each do |callback_name|
            full_callback_name = "#{callback_name.to_s}_for_#{association_name.to_s}"
            defined_callbacks = options[callback_name.to_sym]
            if options.has_key?(callback_name.to_sym)
              class_inheritable_reader full_callback_name.to_sym
              write_inheritable_array(full_callback_name.to_sym, [defined_callbacks].flatten)
            end
          end
        end
    end
  end
end