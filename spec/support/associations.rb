module ActiveRecordTemporalTests
  module Associations
    extend ActiveSupport::Concern

    BASIS_TIME = Time.parse("2000-01-01")

    def build_matcher(node, &block)
      case node
      in [ActiveRecord::Base, Hash]
        build_matcher(node[0], &block).and(build_matcher(node[1], &block))
      in Hash
        have_attributes(node.map do |key, value|
          [key, build_matcher(value, &block)]
        end.to_h)
      in Array
        contain_exactly(*node.map { |child| build_matcher(child, &block) })
      else
        block.call(node)
      end
    end

    class_methods do
      def test_eager_loading(n_steps:, &block)
        examples, current_time = step_up_examples(n_steps)

        describe "temporal querying" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              relation = instance_exec(&block)

              matcher = build_matcher(records) { |record| eq(record) }

              if time
                expect(relation.as_of(time)).to matcher
              else
                travel_to current_time do
                  expect(relation).to matcher
                end
              end
            end
          end
        end

        describe "tags associations" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              relation = instance_exec(&block)

              matcher = build_matcher(records) do |record|
                have_attributes(time_tag: time) if record
              end

              if time
                expect(relation.as_of(time)).to matcher
              else
                travel_to current_time do
                  expect(relation).to matcher
                end
              end
            end
          end
        end
      end

      def test_association_reader(n_steps:)
        examples, current_time = step_up_examples(n_steps)

        describe "temporal querying" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              records.each do |record, expected|
                matcher = build_matcher(expected) { |record| eq(record) }

                if time
                  expect(record.as_of(time)).to matcher
                else
                  travel_to current_time do
                    expect(record).to matcher
                  end
                end
              end
            end
          end
        end

        describe "tags associations" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              records.each do |record, expected|
                matcher = build_matcher(expected) do |record|
                  have_attributes(time_tag: time) if record
                end

                if time
                  expect(record.as_of(time)).to matcher
                else
                  travel_to current_time do
                    expect(record).to matcher
                  end
                end
              end
            end
          end
        end
      end

      def step_up_examples(n_steps)
        examples = n_steps.times.map do |step|
          if step.zero?
            [nil, "without as-of"]
          else
            [BASIS_TIME + step, "as-of t+#{step}"]
          end
        end

        current_time = BASIS_TIME + n_steps

        [examples, current_time]
      end
    end
  end
end
