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

require "md_to_pdf/core"

module Exports::PDF::Common::Markdown
  class MD2PDFExport
    include MarkdownToPDF::Core
    include MarkdownToPDF::Parser
    include Exports::PDF::Common::Common

    def initialize(styling_yml, pdf, hyphenation_language)
      @styles = MarkdownToPDF::Styles.new(styling_yml)
      init_options({ auto_generate_header_ids: false })
      pdf_init_md2pdf_fonts(pdf)
      @hyphens = Hyphen.new(hyphenation_language, true) if hyphenation_language.present?
    end

    def draw_markdown(markdown, pdf, image_loader)
      @pdf = pdf
      @image_loader = image_loader
      @pdf.stroke_color = "000000"
      @pdf.line_width = 1
      @pdf.fill_color = "000000"
      root = parse_markdown(markdown)
      begin
        draw_node(root, pdf_root_options(@styles.page), true)
      rescue Prawn::Errors::CannotFit => e
        Rails.logger.error "Failed to draw markdown field to pdf because of non fitting content: #{e}"
      end
    end

    def image_url_to_local_file(url, _node = nil)
      return nil if url.blank? || @image_loader.nil?

      @image_loader.call(url)
    end

    def hyphenate(text)
      return text if @hyphens.nil?

      @hyphens.hyphenate(text)
    end

    def handle_user_mention_html_tag(tag, node, opts)
      if tag.text.blank?
        # <mention class="mention" data-id="3" data-type="user" data-text="@Some User">
        text = tag.attr("data-text")
        if text.present? && !node.next.respond_to?(:string_content) && node.next.string_content != text
          return [text_hash(text, opts)]
        end
      end
      # <mention class="mention" data-id="3" data-type="user" data-text="@Some User">@Some User</mention>
      # the node text is used.
      []
    end

    def handle_wp_mention_html_tag(tag, node, opts)
      # <mention class="mention" data-id="185" data-type="work_package" data-text="#185">#185</mention>
      # <mention class="mention" data-id="185" data-type="work_package" data-text="##185">##185</mention>
      # <mention class="mention" data-id="185" data-type="work_package" data-text="###185">###185</mention>
      next_node = node&.next # there is no markdown node in a html table
      if next_node && next_node.type == :text && next_node.respond_to?(:string_content)
        # clear the text content, so it does not get rendered
        next_node.string_content = ""
      end
      wp_mention_macro(tag.attr("data-text") || "", tag.attr("data-id") || "", opts)
    end

    def expand_wp_mention(work_package, content)
      detail_level = content.count("#")
      return content if detail_level == 1

      # ##1234: {Type} #{ID}: {Subject}
      content = "#{work_package.type} ##{work_package.id}: #{work_package.subject}"
      return content if detail_level == 2

      # ###1234: {Status} {Type} #{ID}: {Subject} ({Start Date} - {End Date})
      "#{work_package.status.name} #{content}#{work_package_dates(work_package)}"
    end

    def wp_mention_macro(content, id, opts)
      id = id[/\d+/]
      return [text_hash(content, opts)] if id.blank?

      work_package = WorkPackage.find_by(id: id)
      return [text_hash(content, opts)] unless work_package&.visible?

      content = expand_wp_mention(work_package, content)
      [text_hash(content, opts.merge({ link: url_helpers.work_package_url(id) }))]
    end

    def work_package_dates(work_package)
      return "" if work_package.start_date.blank? && work_package.due_date.blank?

      if work_package.due_date.present? && work_package.start_date == work_package.due_date
        return " (#{format_date(work_package.due_date)})"
      end

      work_package_date_range(work_package)
    end

    def work_package_date_range(work_package)
      content = [
        work_package.start_date.present? ? format_date(work_package.start_date) : I18n.t("label_no_start_date"),
        work_package.due_date.present? ? format_date(work_package.due_date) : I18n.t("label_no_due_date")
      ].join(" - ")
      " (#{content})"
    end

    def handle_mention_html_tag(tag, node, opts)
      type = tag.attr("data-type")
      if type == "work_package"
        handle_wp_mention_html_tag(tag, node, opts)
      elsif type == "user"
        handle_user_mention_html_tag(tag, node, opts)
      else
        []
      end
    end

    def handle_unknown_inline_html_tag(tag, node, opts)
      result = if tag.name == "mention"
                 handle_mention_html_tag(tag, node, opts)
               else
                 # unknown/unsupported html tags eg. <foo>hi</foo> are ignored
                 # but scanned for supported or text children
                 data_inlinehtml_tag(tag, node, opts)
               end
      [result, opts]
    end

    def handle_unknown_html_tag(tag, node, opts)
      if tag.name == "mention"
        [handle_mention_html_tag(tag, node, opts), opts]
      else
        # unknown/unsupported html tags eg. <foo>hi</foo> are ignored
        # but scanned for supported or text children [true, ...]
        [true, opts]
      end
    end

    def warn(text, element, node)
      Rails.logger.warn "PDF-Export: #{text}\nGot #{element} at #{node.source_position.inspect}\n\n"
    end
  end

  def markdown_writer(styling_yml)
    MD2PDFExport.new(styling_yml, pdf, hyphenation_language)
  end

  def write_markdown!(markdown, styling_yml)
    return if markdown.blank?

    markdown_writer(styling_yml)
      .draw_markdown(markdown, pdf, ->(src) {
        with_images? ? attachment_image_filepath(src) : nil
      })
  end
end
