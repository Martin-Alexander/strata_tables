module StrataTablesTest
  module Associations
    extend ActiveSupport::Concern

    def build_matcher(node, &block)
      case node
      in [ActiveRecord::Base, Hash]
        build_matcher(node[0], &block).and(build_matcher(node[1], &block))
      in Hash
        have_attributes(node.each do |key, value|
          [key, build_matcher(value, &block)]
        end.to_h)
      in Array
        be_empty if node.empty?

        contain_exactly(*node.map { |child| build_matcher(child, &block) })
      else
        block.call(node)
      end
    end

    class_methods do
      def test_eager_loading(n_steps:, &block)
        examples = n_steps.times.map do |step|
          if step.zero?
            [nil, "without as-of"]
          else
            [Time.parse("2000-01-01") + step, "as-of t+#{step}"]
          end
        end

        describe "temporal querying" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              relation = instance_exec(&block)

              as_of_relation = time ? relation.as_of(time) : relation

              matcher = build_matcher(records) { |record| eq(record) }

              expect(as_of_relation.load).to matcher
            end
          end
        end

        describe "tagging record and associations with as-of" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              relation = instance_exec(&block)

              as_of_relation = time ? relation.as_of(time) : relation

              matcher = build_matcher(records) do |record|
                have_attributes(period_as_of: time)
              end

              expect(as_of_relation.load).to matcher
            end
          end
        end
      end

      def test_association_reader(n_steps:, &block)
        examples = n_steps.times.map do |step|
          if step.zero?
            [nil, "without as-of"]
          else
            [Time.parse("2000-01-01") + step, "as-of t+#{step}"]
          end
        end

        describe "temporal querying" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              records.each do |ar_record, expected|
                ar_record = time ? ar_record.as_of(time) : ar_record

                matcher = build_matcher(expected) { |ar_record| eq(ar_record) }

                expect(ar_record).to matcher
              end
            end
          end
        end

        describe "tagging associated recorded" do
          examples.each do |(time, name)|
            it name do
              records = timeline[time]

              records.each do |ar_record, expected|
                ar_record = time ? ar_record.as_of(time) : ar_record

                matcher = build_matcher(expected) do |ar_record|
                  have_attributes(period_as_of: time)
                end

                expect(ar_record).to matcher
              end
            end
          end
        end
      end
    end
  end
end
