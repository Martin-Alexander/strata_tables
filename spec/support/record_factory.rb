module RecordFactory
  def build_records(&block)
    block.call.each do |model, records|
      records.each do |method_name, attrs|
        let!(method_name) { model.constantize.find_or_create_by!(attrs) }
      end
    end
  end
end
