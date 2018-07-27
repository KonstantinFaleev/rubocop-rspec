# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      module FactoryBot
        # Always declare attribute values as blocks.
        #
        # @example
        #   # bad
        #   kind [:active, :rejected].sample
        #
        #   # good
        #   kind { [:active, :rejected].sample }
        #
        #   # bad
        #   closed_at 1.day.from_now
        #
        #   # good
        #   closed_at { 1.day.from_now }
        #
        #   # bad
        #   count 1
        #
        #   # good
        #   count { 1 }
        class AttributeDefinedStatically < Cop
          MSG = 'Use a block to set a dynamic value to an attribute.'.freeze

          ATTRIBUTE_DEFINING_METHODS = %i[factory trait transient ignore].freeze

          UNPROXIED_METHODS = %i[
            __send__
            __id__
            nil?
            send
            object_id
            extend
            instance_eval
            initialize
            block_given?
            raise
            caller
            method
          ].freeze

          DEFINITION_PROXY_METHODS = %i[
            add_attribute
            after
            association
            before
            callback
            ignore
            initialize_with
            sequence
            skip_create
            to_create
          ].freeze

          RESERVED_METHODS =
            DEFINITION_PROXY_METHODS +
            UNPROXIED_METHODS +
            ATTRIBUTE_DEFINING_METHODS

          def_node_matcher :value_matcher, <<-PATTERN
            (send nil? !#reserved_method? $...)
          PATTERN

          def_node_search :factory_attributes, <<-PATTERN
            (block (send nil? #attribute_defining_method? ...) _ { (begin $...) $(send ...) } )
          PATTERN

          def on_block(node)
            factory_attributes(node).to_a.flatten.each do |attribute|
              next if proc?(attribute)
              add_offense(attribute, location: :expression)
            end
          end

          def autocorrect(node)
            if !method_uses_parens?(node.location)
              autocorrect_without_parens(node)
            elsif value_hash_without_braces?(node.descendants.first)
              autocorrect_hash_without_braces(node)
            else
              autocorrect_replacing_parens(node)
            end
          end

          private

          def proc?(attribute)
            value_matcher(attribute).to_a.all?(&:block_pass_type?)
          end

          def value_hash_without_braces?(node)
            node.hash_type? && !node.braces?
          end

          def method_uses_parens?(location)
            return false unless location.begin && location.end
            location.begin.source == '(' && location.end.source == ')'
          end

          def autocorrect_hash_without_braces(node)
            autocorrect_replacing_parens(node, ' { { ', ' } }')
          end

          def autocorrect_replacing_parens(node,
                                           start_token = ' { ',
                                           end_token = ' }')
            lambda do |corrector|
              corrector.replace(node.location.begin, start_token)
              corrector.replace(node.location.end, end_token)
            end
          end

          def autocorrect_without_parens(node)
            lambda do |corrector|
              arguments = node.descendants.first
              expression = arguments.location.expression
              corrector.insert_before(expression, '{ ')
              corrector.insert_after(expression, ' }')
            end
          end

          def reserved_method?(method_name)
            RESERVED_METHODS.include?(method_name)
          end

          def attribute_defining_method?(method_name)
            ATTRIBUTE_DEFINING_METHODS.include?(method_name)
          end
        end
      end
    end
  end
end
