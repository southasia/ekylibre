# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2016 Brice Texier, David Joulin
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
# == Table: intervention_parameters
#
#  created_at              :datetime         not null
#  creator_id              :integer
#  event_participation_id  :integer
#  group_id                :integer
#  id                      :integer          not null, primary key
#  intervention_id         :integer          not null
#  lock_version            :integer          default(0), not null
#  new_container_id        :integer
#  new_group_id            :integer
#  new_variant_id          :integer
#  outcoming_product_id    :integer
#  position                :integer          not null
#  product_id              :integer
#  quantity_handler        :string
#  quantity_indicator_name :string
#  quantity_population     :decimal(19, 4)
#  quantity_unit_name      :string
#  quantity_value          :decimal(19, 4)
#  reference_name          :string           not null
#  type                    :string
#  updated_at              :datetime         not null
#  updater_id              :integer
#  variant_id              :integer
#  working_zone            :geometry({:srid=>4326, :type=>"multi_polygon"})
#

# An intervention output represents a product which is produced by the
# intervention. The output generate a product with the given quantity.
class InterventionOutput < InterventionProductParameter
  belongs_to :intervention, inverse_of: :outputs
  belongs_to :product, dependent: :destroy
  has_one :product_movement, as: :originator
  validates :variant, presence: true

  after_save do
    if variant
      output = product
      output ||= variant.products.new unless output
      # output.name = ''
      # output.attributes = product_attributes
      output.save!

      movement = product_movement
      movement = output.movements.build unless movement
      movement.delta = quantity_population
      movement.started_at = intervention.started_at

      update_columns(product_id: output.id) # , movement_id: movement.id)
    end
  end

  def earn_amount_computation
    options = { quantity: quantity_population, unit_name: product.unit_name }
    if product
      outgoing_parcel = product.outgoing_parcel_item
      if outgoing_parcel && outgoing_parcel.sale_item
        options[:sale_item] = outgoing_parcel.sale_item
        return InterventionParameter::AmountComputation.quantity(:sale, options)
      else
        options[:catalog_usage] = :sale
        options[:catalog_item] = product.default_catalog_item(options[:catalog_usage])
        return InterventionParameter::AmountComputation.quantity(:catalog, options)
      end
    elsif variant
      options[:catalog_usage] = :sale
      options[:catalog_item] = variant.default_catalog_item(options[:catalog_usage])
      return InterventionParameter::AmountComputation.quantity(:catalog, options)
    else
      return InterventionParameter::AmountComputation.failed
    end
  end
end