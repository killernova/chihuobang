class Groupbuy < ActiveRecord::Base
	belongs_to :user
	belongs_to :logistic
	
	has_many :participants, dependent: :destroy
	has_many :comments, dependent: :destroy
	has_many :photos, :inverse_of => :groupbuy, :dependent => :destroy
	accepts_nested_attributes_for :photos, allow_destroy: true

	validates :body,  length: {in: 5..5000}
	validates :title,  presence: {message: I18n.t('errors.messages.blank')}
	validates :end_time, presence: true
	validates :start_time, presence: true
	validates :goods_unit,  presence: true
	validates :price,  presence: true
	validates :market_price, presence: true
	validates :groupbuy_price, presence: true	
	validates :goods_minimal,  presence: true
	validates :goods_maximal,  presence: true
	validate :check_duration

	def check_duration
		return if self.start_time.blank? || self.end_time.blank?
		if self.start_time > self.end_time
			errors.add(:base, :duration)
		end
	end

 	default_scope {order 'recommend DESC, created_at DESC'}

 	def current_price
	    return self.price  if Time.now > self.end_time
	    self.groupbuy_price
	end

	def current_market_price
	    return self.market_price*1.2  if Time.now > self.end_time
	    self.market_price
	end

end
