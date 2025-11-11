module ActiveRecordTemporalTests
  module TableFactory
    def table(name, **options, &block)
      conn.create_table name, **options do |t|
        instance_exec(t, &block) if block
      end

      Array(options[:primary_key] || :id).each do |col|
        randomize_sequence(name, col)
      end
    end

    def as_of_table name, **options, &block
      options = options.merge(primary_key: [:id, :version])

      table name, **options do |t|
        t.bigint :id
        t.bigserial :version
        t.tstzrange :period, null: false

        instance_exec(t, &block) if block
      end
    end

    def system_versioned_table(name, **options, &block)
      source_table_name = name
      history_table_name = "#{name}_history"

      table source_table_name, **options, &block

      primary_key = Array(conn.primary_key(source_table_name))

      table history_table_name, primary_key: [:id, :system_period] do |t|
        instance_exec(t, &block) if block

        t.bigint :id, null: false
        t.tstzrange :system_period, null: false
      end

      columns = conn.columns(source_table_name).map(&:name)
      conn.create_versioning_hook(source_table_name, history_table_name, columns: columns)
    end

    private

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
  end
end
