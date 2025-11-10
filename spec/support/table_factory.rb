module StrataTablesTest
  module TableFactory
    def table(name, as_of: false, **options, &block)
      if as_of
        as_of_table(name, **options, &block)
      else
        regular_table(name, **options, &block)
      end
    end

    def system_versioned_table(name, **options, &block)
      source_table_name = name
      history_table_name = "#{name}_history"

      regular_table(source_table_name, **options, &block)

      primary_key = Array(conn.primary_key(source_table_name))
      history_table_options = {primary_key: primary_key + [:system_period]}.merge(options)

      regular_table(history_table_name, **history_table_options) do |t|
        instance_exec(t, &block) if block

        t.bigint :id, null: false
        t.tstzrange :system_period, null: false
      end

      columns = conn.columns(source_table_name).map(&:name)
      conn.create_versioning_hook(source_table_name, history_table_name, columns: columns)
    end

    private

    def as_of_table(name, **options, &block)
      ensure_btree_gist_enabled

      options = options.merge(primary_key: [:id, :version_id])

      conn.create_table name, **options do |t|
        t.bigint :id
        t.bigserial :version_id
        t.tstzrange :period, null: false
        t.exclusion_constraint("id WITH =, period WITH &&", using: :gist)

        instance_exec(t, &block) if block
      end
    end

    def regular_table(name, **options, &block)
      conn.create_table name, **options do |t|
        instance_exec(t, &block) if block
      end

      Array(options[:primary_key] || :id).each do |col|
        randomize_sequence(name, col)
      end
    end

    def randomize_sequence(table, column)
      offset = Math.exp(2 + rand * (10 - 2)).to_i

      quoted_table_name = conn.quote_table_name(table)

      conn.execute(<<~SQL)
        SELECT setval(
          pg_get_serial_sequence('#{quoted_table_name}', '#{column}'),
          #{offset}
        )
      SQL
    end

    def ensure_btree_gist_enabled
      conn.enable_extension(:btree_gist) unless conn.extension_enabled?(:btree_gist)
    end
  end
end
