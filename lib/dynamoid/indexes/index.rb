# encoding: utf-8
module Dynamoid #:nodoc:
  module Indexes

    # The class contains all the information an index contains, including its keys and which attributes it covers.
    class Index
      attr_accessor :prefix, :source, :name, :hash_keys, :range_keys
      alias_method :range_key?, :range_keys

      # Create a new index. Pass either :range => true or :range => :column_name to create a ranged index on that column.
      #
      # @param [Class] source the source class for the index
      # @param [Symbol] name the name of the index
      #
      # @since 0.2.0
      def initialize(source, name, options = {})
        @source = source
        @prefix = options[:prefix] || source.to_s.downcase

        if options.delete(:range)
          @range_keys = sort(name)
        elsif options[:range_key]
          @range_keys = sort(options[:range_key])
        end
        @hash_keys = sort(name)
        @name = sort([hash_keys, range_keys])

        raise Dynamoid::Errors::InvalidField, 'A key specified for an index is not a field' unless keys.all?{|n| source.attributes.include?(n)}
      end

      # Sort objects into alphabetical strings, used for composing index names correctly (since we always assume they're alphabetical).
      #
      # @example find all users by first and last name
      #   sort([:gamma, :alpha, :beta, :omega]) # => [:alpha, :beta, :gamma, :omega]
      #
      # @since 0.2.0
      def sort(objs)
        Array(objs).flatten.compact.uniq.collect(&:to_s).sort.collect(&:to_sym)
      end

      # Return the array of keys this index uses for its table.
      #
      # @since 0.2.0
      def keys
        [Array(hash_keys) + Array(range_keys)].flatten.uniq
      end

      # Return the table name for this index.
      #
      # @since 0.2.0
      def table_name
        "#{Dynamoid::Config.namespace}_index_#{prefix}_#{name.collect(&:to_s).collect(&:pluralize).join('_and_')}"
      end

      # Given either an object or a list of attributes, generate a hash key and a range key for the index. Optionally pass in
      # true to changed_attributes for a list of all the object's dirty attributes in convenient index form (for deleting stale
      # information from the indexes).
      #
      # @param [Object] attrs either an object that responds to :attributes, or a hash of attributes
      #
      # @return [Hash] a hash with the keys :hash_value and :range_value
      #
      # @since 0.2.0
      def values(attrs, changed_attributes = false)
        if changed_attributes
          hash = {}
          attrs.changes.each {|k, v| hash[k.to_sym] = v.first}
          attrs = attrs.attributes.merge hash
        elsif attrs.respond_to? :attributes
          attrs = attrs.attributes
        end

        {}.tap do |hash|
          if hash_keys.any? { |key| attrs[key] }
            hash[:hash_value] = hash_keys.collect{|key| attrs[key]}.join('.')
          end
          hash[:range_value] = range_keys.inject(0.0) {|sum, key| sum + attrs[key].to_f} if self.range_key?
        end
      end

      # Save an object to this index, merging it with existing ids if there's already something present at this index location.
      # First, though, delete this object from its old indexes (so the object isn't listed in an erroneous index).
      #
      # @since 0.2.0
      def save(obj)
        return true if index_current? obj

        delete obj, true

        update_index obj, false do |item|
          item.add ids: [obj.id]

          if obj.respond_to? :ttl
            item.set ttl: obj.ttl.to_f
          end
        end
      end

      # Delete an object from this index, preserving existing ids if there are any, and failing gracefully if for some reason the
      # index doesn't already have this object in it.
      #
      # @since 0.2.0
      def delete(obj, changed_attributes = false)
        return true if obj.new_record?

        update_index obj, changed_attributes do |item|
          item.delete ids: [obj.id]
        end
      end

      private

      def index_current?(obj)
        (keys & obj.changes.keys.map(&:to_sym)).empty?
      end

      def update_index(obj, changed_attributes, &block)
        hash_value, range_value = values(obj, changed_attributes).values_at :hash_value, :range_value

        return true if hash_value.blank? || (!range_value.nil? && range_value.blank?)

        Dynamoid::Adapter.update_item table_name, hash_value, range_key: range_value, &block
      end
    end
  end
end
