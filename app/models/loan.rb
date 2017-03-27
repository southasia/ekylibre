# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2017 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: loans
#
#  accounted_at               :datetime
#  amount                     :decimal(19, 4)   not null
#  bank_guarantee_account_id  :integer
#  bank_guarantee_amount      :integer
#  cash_id                    :integer          not null
#  created_at                 :datetime         not null
#  creator_id                 :integer
#  currency                   :string           not null
#  custom_fields              :jsonb
#  id                         :integer          not null, primary key
#  insurance_account_id       :integer
#  insurance_percentage       :decimal(19, 4)   not null
#  insurance_repayment_method :string
#  interest_account_id        :integer
#  interest_percentage        :decimal(19, 4)   not null
#  journal_entry_id           :integer
#  lender_id                  :integer          not null
#  loan_account_id            :integer
#  lock_version               :integer          default(0), not null
#  name                       :string           not null
#  ongoing_at                 :datetime
#  repaid_at                  :datetime
#  repayment_duration         :integer          not null
#  repayment_method           :string           not null
#  repayment_period           :string           not null
#  shift_duration             :integer          default(0), not null
#  shift_method               :string
#  started_on                 :date             not null
#  state                      :string
#  updated_at                 :datetime         not null
#  updater_id                 :integer
#  use_bank_guarantee         :boolean
#
class Loan < Ekylibre::Record::Base
  include Attachable
  include Customizable
  enumerize :repayment_method, in: [:constant_rate, :constant_amount], default: :constant_amount
  enumerize :shift_method, in: [:immediate_payment, :anatocism], default: :immediate_payment
  enumerize :repayment_period, in: [:month, :year, :trimester, :semester], default: :month, predicates: { prefix: true }
  enumerize :insurance_repayment_method, in: [:initial, :to_repay], default: :to_repay, predicates: true
  refers_to :currency
  belongs_to :cash
  belongs_to :journal_entry
  belongs_to :lender, class_name: 'Entity'
  belongs_to :third, foreign_key: :lender_id, class_name: 'Entity' # alias for lender
  belongs_to :loan_account,         class_name: 'Account'
  belongs_to :interest_account,     class_name: 'Account'
  belongs_to :insurance_account, class_name: 'Account'
  belongs_to :bank_guarantee_account, class_name: 'Account'
  has_many :repayments, -> { order(:position) }, class_name: 'LoanRepayment', dependent: :destroy, counter_cache: false
  has_one :journal, through: :cash
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :accounted_at, :ongoing_at, :repaid_at, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years } }, allow_blank: true
  validates :amount, :insurance_percentage, :interest_percentage, presence: true, numericality: { greater_than: -1_000_000_000_000_000, less_than: 1_000_000_000_000_000 }
  validates :bank_guarantee_amount, numericality: { only_integer: true, greater_than: -2_147_483_649, less_than: 2_147_483_648 }, allow_blank: true
  validates :cash, :currency, :lender, :repayment_method, :repayment_period, :third, presence: true
  validates :name, presence: true, length: { maximum: 500 }
  validates :repayment_duration, :shift_duration, presence: true, numericality: { only_integer: true, greater_than: -2_147_483_649, less_than: 2_147_483_648 }
  validates :started_on, presence: true, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.today + 50.years }, type: :date }
  validates :state, length: { maximum: 500 }, allow_blank: true
  validates :use_bank_guarantee, inclusion: { in: [true, false] }, allow_blank: true
  # ]VALIDATORS]
  validates :loan_account_id, :interest_account_id, presence: true

  state_machine :state, initial: :draft do
    state :draft
    state :ongoing
    state :repaid

    event :confirm do
      transition draft: :ongoing, if: :draft?
    end
    event :repay do
      transition ongoing: :repaid, if: :ongoing?
    end
  end

  before_validation(on: :create) do
    self.state = :draft
    self.currency ||= cash.currency if cash
    self.shift_duration ||= 0
  end

  before_validation do
    self.currency ||= cash.currency if cash
    self.shift_duration ||= 0
  end

  validate do
    if self.currency && cash
      errors.add(:currency, :invalid) unless self.currency == cash.currency
    end
  end

  after_commit do
    generate_repayments
  end

  # Prevents from deleting if entry exist
  protect on: :destroy do
    journal_entry && ongoing?
  end

  bookkeep do |b|
    # when money arrive (ongoing_at)
    # when first payment started (started_on)

    ongoing_on = ongoing_at.to_date

    existing_financial_year = FinancialYear.on(ongoing_on)

    b.journal_entry(journal, printed_on: ongoing_on, if: ongoing_on <= Time.zone.today && existing_financial_year && ongoing?) do |entry|
      label = tc(:bookkeep, resource: self.class.model_name.human, name: name)

      entry.add_debit(label, cash.account_id, amount, as: :bank)
      entry.add_credit(label, unsuppress { loan_account_id }, amount, as: :loan)

      # puts entry.inspect.red

      if use_bank_guarantee?
        label_guarantee = tc(:bookkeep_guarantee_payment, resource: self.class.model_name.human, name: name)
        entry.add_debit(label_guarantee, unsuppress { bank_guarantee_account_id }, bank_guarantee_amount, as: :bank_guarantee)
        entry.add_credit(label_guarantee, cash.account_id, bank_guarantee_amount, as: :bank)
      end
    end

    true
  end

  def generate_repayments
    period = if repayment_period_month?
               12
             elsif repayment_period_trimester?
               4
             elsif repayment_period_semester?
               2
             else
               1
             end

    length = if repayment_period_month?
               1.month
             elsif repayment_period_trimester?
               3.month
             elsif repayment_period_semester?
               6.month
             else
               1.year
             end

    ids = []
    Calculus::Loan
      .new(
        amount,
        repayment_duration,
        interests:  { interest_amount:  interest_percentage  / 100.0 },
        insurances: { insurance_amount: insurance_percentage / 100.0 },
        period: period,
        length: length,
        shift: self.shift_duration,
        shift_method: shift_method.to_sym,
        insurance_method: insurance_repayment_method,
        started_on: started_on
      )
      .compute_repayments(repayment_method)
      .each do |repayment|
        if r = repayments.find_by(position: repayment[:position])
          r.update_attributes!(repayment)
        else
          r = repayments.create!(repayment)
        end
        ids << r.id
      end
    repayments.destroy(repayments.where.not(id: ids))
    reload
  end
  
  def current_remaining_amount(on = Date.today)
    r = repayments.where('due_on <= ?', on).reorder(:position).last
    return nil unless r
    r.remaining_amount
  end
  
  # why ? we have state machine ?
  def draft?
    state.to_sym == :draft
  end

  def ongoing?
    state.to_sym == :ongoing
  end

  def repaid?
    state.to_sym == :repaid
  end

  def confirm(ongoing_at = nil)
    return false unless can_confirm?
    reload
    self.ongoing_at ||= ongoing_at || Time.zone.now
    save!
    super
  end

  def repay(repaid_at = nil)
    return false unless can_repay?
    reload
    self.repaid_at ||= repaid_at || Time.zone.now
    save!
    super
  end
end
