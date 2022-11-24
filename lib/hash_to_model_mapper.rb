# frozen_string_literal: true

require 'hash_to_model_mapper/version'

require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'
require 'active_support/core_ext/date'
require 'active_support/core_ext/integer'

module HashToModelMapper
  @registry = {}

  def self.register(model_name, type, mapper)
    @registry[model_name] ||= {}
    @registry[model_name][type] = mapper
  end

  def self.registry
    @registry
  end

  def self.defined_mappings_for(model_name)
    @registry[model_name]
  end

  def self.defined_fields_for(model_name)
    defined_mappings_for(model_name).values
                                    .map(&:attributes)
                                    .map(&:keys)
                                    .flatten
                                    .uniq
  end

  def self.define(&block)
    definition_proxy = DefinitionProxy.new
    definition_proxy.instance_eval(&block)
  end

  def self.call(model_name, type = nil, source)
    raise('source needs to be present') unless source.present?

    instance = model_name.to_s.classify.constantize.new
    instance.readonly! if instance.respond_to? :readonly!
    mapper = registry[model_name][type] || raise("Mapper not defined for #{model_name} -> #{type}")
    attributes = mapper.attributes

    case source
    when Hash
      source = source.with_indifferent_access
      get_value = ->(path) { source.dig(*path) }
    else
      get_value = ->(path) { path.reduce(source) { |source, method| source.__send__(method) } }
    end

    attributes.each do |attribute_name, path|
      value = if path.respond_to? :call
                path.call(source)
              elsif path.first.respond_to? :call
                path.first.call(source)
              else
                get_value.call(path)
              end

      if (transformer = mapper.transformers[attribute_name])
        if transformer.is_a? Hash
          old_value = value
          value = transformer.with_indifferent_access[value]

          if value.nil? && !transformer.keys.any? { |key| key == :nil }
            raise("Key not present in tansformer: \
                  Wrong key: #{old_value}\
                  Valid keys: #{transformer.keys.inspect}\
                  Path: #{path}")
          end

        elsif transformer.respond_to? :call
          value = transformer.call(value)
        else
          raise('transformer is neither a hash or a callable object')
        end
      end
      instance.__send__("#{attribute_name}=", value)
    end

    instance.id = nil if instance.respond_to? :id

    instance
  end

  private
end

class DefinitionProxy
  def mapper(model_name, type: :none, &block)
    mapper = Mapper.new
    mapper.instance_eval(&block)
    HashToModelMapper.register(model_name, type, mapper)
  end
end

class Mapper
  def initialize
    @transformers = {}
    @attributes = {}
  end

  attr_reader :attributes, :transformers

  def method_missing(name, *path, **args, &block)
    @transformers[name] = args[:transform]
    @attributes[name] = path.presence || block
  end
end
