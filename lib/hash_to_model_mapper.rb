# frozen_string_literal: true

require 'hash_to_model_mapper/version'

require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'

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
    fail("source needs to be present") unless source.present?

    instance = model_name.to_s.classify.constantize.new
    instance.readonly!
    mapper = registry[model_name][type] || fail("Mapper not defined for #{model_name} -> #{type}")
    attributes = mapper.attributes

    case source
    when Hash
      source = source.with_indifferent_access
      get_value = ->(path) { source.dig(*path) }
    when ApplicationRecord 
      get_value = ->(path) { path.reduce(source) { |source, method| source.__send__(method) } }
    else
      fail("Type not supported Hash/ApplicationRecord, however it was #{source.class}: #{source}")
    end

    attributes.each do |attribute_name, path|
      value = if path.respond_to? :call
                path.call(source)
              elsif path.first.respond_to? :call
                path.first.call(source)
              else
                get_value.(path)
              end

      if (transformer = mapper.transformers[attribute_name])
        if transformer.is_a? Hash
          value = transformer.with_indifferent_access[value] || fail("Key not present in tansformer: #{value}")
        elsif transformer.respond_to? :call
          value = transformer.call(value)
        else
          fail('transformer is neither a hash or a callable object')
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
