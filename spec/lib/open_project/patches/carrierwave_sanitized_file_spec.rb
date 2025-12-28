# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++
require "spec_helper"

# Adapt the carrierwave sanitized file tests to the content type detector
RSpec.describe OpenProject::Patches::CarrierwaveSanitizedFile do
  let(:file) { FileHelpers.mock_uploaded_file(name: "original-filename.txt") }

  it "uses the first one when multiple mime types are given using a semicolon" do
    allow(file).to receive(:content_type).and_return("image/png; text/html")

    sanitized_file = CarrierWave::SanitizedFile.new(file)

    expect(sanitized_file.content_type).to eq("image/png")
  end

  it "uses the first one when multiple mime types are given using a comma" do
    allow(file).to receive(:content_type).and_return("image/png, text/html")

    sanitized_file = CarrierWave::SanitizedFile.new(file)

    expect(sanitized_file.content_type).to eq("image/png")
  end

  it "drops content type parameters" do
    allow(file).to receive(:content_type).and_return("text/html; charset=utf-8")

    sanitized_file = CarrierWave::SanitizedFile.new(file)

    expect(sanitized_file.content_type).to eq("text/html")
  end
end
