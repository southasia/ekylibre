# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2014 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: product_readings
#
#  absolute_measure_value_unit  :string(255)
#  absolute_measure_value_value :decimal(19, 4)
#  boolean_value                :boolean          not null
#  choice_value                 :string(255)
#  created_at                   :datetime         not null
#  creator_id                   :integer
#  decimal_value                :decimal(19, 4)
#  geometry_value               :spatial({:srid=>
#  id                           :integer          not null, primary key
#  indicator_datatype           :string(255)      not null
#  indicator_name               :string(255)      not null
#  integer_value                :integer
#  lock_version                 :integer          default(0), not null
#  measure_value_unit           :string(255)
#  measure_value_value          :decimal(19, 4)
#  originator_id                :integer
#  originator_type              :string(255)
#  point_value                  :spatial({:srid=>
#  product_id                   :integer          not null
#  read_at                      :datetime         not null
#  string_value                 :text
#  updated_at                   :datetime         not null
#  updater_id                   :integer
#
require 'test_helper'

class ProductReadingTest < ActiveSupport::TestCase

end
