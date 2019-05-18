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

  def self.define(&block)
    definition_proxy = DefinitionProxy.new
    definition_proxy.instance_eval(&block)
  end

  def self.call(model_name, type = nil, hash)
    instance = model_name.to_s.classify.constantize.new
    instance.readonly!
    mapper = registry[model_name][type]
    attributes = mapper.attributes
    hash = hash.with_indifferent_access

    attributes.each do |attribute_name, path|
      value = hash.dig(*path)
      instance.__send__("#{attribute_name}=", value)
    end

    instance
  end
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
    @attributes = {}
  end

  attr_reader :attributes

  def method_missing(name, *path)
    @attributes[name] = path
  end
end
