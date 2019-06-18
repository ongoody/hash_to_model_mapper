# frozen_string_literal: true

class Ad
  attr_accessor :title, :description, :cover_url, :price, :type, :next_check_at

  # Simulating ActiveRecord #readonly!
  def readonly!
    true
  end
end

RSpec.describe HashToModelMapper do
  before do
    described_class.define do
      mapper :ad, type: :data_source_1 do
        title 'Title'
        description 'Details', 'Desc'
        cover_url 'Photos', 0
        price 'Price', transform: ->(value) { value.to_i * 100 }
        type { 'type_1' }
        next_check_at ->(hash) { 20.days.from_now.to_date if hash['Price'].present? }
      end
    end
  end

  let(:hash) do
    {
      'Title': 'the title',
      'Details': { 'Desc': 'the description' },
      'Photos': %w[photo_1 photo_2],
      'Price': '200_000'
    }
  end

  subject { described_class.call(:ad, :data_source_1, hash) }

  it 'maps one level attributes' do
    expect(subject.title).to eq('the title')
  end

  it 'maps nested attributes' do
    expect(subject.description).to eq('the description')
  end

  it 'maps array elements' do
    expect(subject.cover_url).to eq('photo_1')
  end

  it 'maps array elements' do
    expect(subject.price).to eq(200_000_00)
  end

  it 'maps fixes values' do
    expect(subject.type).to eq('type_1')
  end

  it 'maps lambda values' do
    expect(subject.next_check_at).to eq(20.days.from_now.to_date)
  end
end
