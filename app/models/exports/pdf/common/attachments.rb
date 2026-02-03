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

require "mini_magick"

module Exports::PDF::Common::Attachments
  def resize_image(file_path)
    tmp_file = temp_image_file(File.extname(file_path))

    image = MiniMagick::Image.open(file_path)
    image.resize("x800>")
    image.write(tmp_file)

    tmp_file
  end

  def pdf_embeddable?(content_type)
    %w[image/jpeg image/png image/gif].include?(content_type)
  end

  def delete_all_resized_images
    @resized_images&.each(&:close!)
    @resized_images = []
  end

  def attachment_image_local_file(attachment)
    attachment.file.local_file
  rescue StandardError => e
    Rails.logger.error "Failed to access attachment #{attachment.id} file: #{e}"
    nil # return nil as if the id was wrong and the attachment obj has not been found
  end

  def attachment_image_filepath(src)
    # images are embedded into markup with the api-path as img.src
    attachment = attachment_by_api_content_src(src)
    return nil if attachment.nil? || !pdf_embeddable?(attachment.content_type)

    local_file = attachment_image_local_file(attachment)
    return nil if local_file.nil?

    filename = local_file.path
    filename = convert_gif_to_png(filename) if attachment.content_type == "image/gif"

    resize_image(filename)
  end

  def temp_image_file(extension)
    tmp_file = Tempfile.new(["temp_image", extension])
    @resized_images = [] if @resized_images.nil?
    @resized_images << tmp_file
    tmp_file.path
  end

  def convert_gif_to_png(filename)
    tmp_file = temp_image_file(".png")

    image = MiniMagick::Image.open(filename)
    image.frames.first.write(tmp_file)
    tmp_file
  end

  def attachment_by_api_content_src(src)
    return nil if src.empty?

    # we accept absolut linked images
    # (but not hot-linked from elsewhere: https://example.com/another_api/attachments/1/somefile.png)
    #
    # #{api_url_helpers.root_path}api/v3/attachments/:id/content (our default api path)
    # #{api_url_helpers.root_path}attachments/:id/filename.ext (e.g. inserted by drag and drop from the files tab)

    attachment_regex = %r{/attachments/(\d+)/}
    return nil unless src.start_with?(api_url_helpers.root_path) && src.match?(attachment_regex)

    attachments_id = src.scan(attachment_regex).first.first
    attachment = Attachment.find_by(id: attachments_id.to_i)
    return nil if attachment.nil?
    return nil unless attachment.visible?

    attachment
  rescue StandardError
    # if the attachment is not found or the id is invalid, we return nil
    Rails.logger.error "Failed to access attachment #{src}"
    nil
  end
end
