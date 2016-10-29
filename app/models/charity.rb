class Charity < ActiveRecord::Base
  validates :name, presence: true

  def credit_amount(amount)
    with_lock do
      reload
      new_total = total + amount
      update_attribute :total, new_total
    end
  end

  def self.random
    order('RANDOM()').first
  end
end
