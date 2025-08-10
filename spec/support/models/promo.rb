class Promo < ActiveRecord::Base
  has_many :order_line_items

  has_many :history, foreign_key: :id, class_name: "HistoryPromo"
end

class HistoryPromo < ActiveRecord::Base
  self.table_name = "strata_promos"

  def temporal_id
    self[:id]
  end
end
