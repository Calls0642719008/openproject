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
require "carrierwave"

##
# Adapt carrierwave to match fixes for CVE-2023-49090.
# https://github.com/carrierwaveuploader/carrierwave/security/advisories/GHSA-vfmv-jfc5-pjjw
module OpenProject::Patches::CarrierwaveSanitizedFile
  extend ActiveSupport::Concern

  included do
    def content_type
      return @content_type if @content_type

      if @file.respond_to?(:content_type) and @file.content_type
        Marcel::MimeType.for(declared_type: @file.content_type.to_s.chomp)
      elsif path
        @content_type = Attachment.content_type_for(path)
      end
    end

    # create the directory if it doesn't exist
    # Overwritten to avoid ruby 2.7 deprecations
    def mkdir!(path, directory_permissions)
      options = {}
      options[:mode] = directory_permissions if directory_permissions
      FileUtils.mkdir_p(File.dirname(path), **options)
    end
  end
end

OpenProject::Patches.patch_gem_version "carrierwave", "1.3.4" do
  CarrierWave::SanitizedFile.include OpenProject::Patches::CarrierwaveSanitizedFile
end
