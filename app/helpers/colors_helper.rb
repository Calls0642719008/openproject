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

module ColorsHelper
  include Primer::JoinStyleArgumentsHelper

  def options_for_colors(colored_thing)
    colors = []
    Color.find_each do |c|
      options = {}
      options[:name] = c.name
      options[:value] = c.id
      options[:selected] = true if c.id == colored_thing.color_id

      colors.push(options)
    end
    colors.to_json
  end

  def selected_color(colored_thing)
    colored_thing.color_id
  end

  #
  # Styles to display colors itself (e.g. for the colors autocompleter)
  ##
  def color_css
    Color.find_each do |color|
      set_background_colors_for(class_name: ".#{hl_inline_class('color', color)}_dot::before", color:)
      set_foreground_colors_for(class_name: ".#{hl_inline_class('color', color)}_text", color:)
    end
  end

  #
  # Styles to display the color of attributes (type, status etc.) for example in the WP view
  ##
  def resources_scope_color_css(name, scope, inline_foreground: false)
    scope.includes(:color).find_each do |entry|
      resource_color_css(name, entry, inline_foreground: inline_foreground)
    end
  end

  # Render the highlighting color for the project phase definition.
  def project_phase_color_css
    Project::PhaseDefinition.includes(:color).find_each do |definition|
      resource_color_css("project_phase_definition", definition, inline_foreground: true)

      set_foreground_colors_for(
        class_name: ".#{hl_inline_class('project_phase_definition', definition.id)}",
        color: definition.color
      )
    end
  end

  def resource_color_css(name, entry, inline_foreground: false)
    color = entry.color

    if color.nil?
      concat ".#{hl_inline_class(name, entry)}::before { display: none }"
      return
    end

    if inline_foreground
      set_foreground_colors_for(class_name: ".#{hl_inline_class(name, entry)}", color:)
    else
      set_background_colors_for(class_name: ".#{hl_inline_class(name, entry)}::before", color:)
    end

    set_background_colors_for(class_name: ".#{hl_background_class(name, entry)}", color:)

    # generic class for color
    set_generic_color_for(class_name: ".#{hl_color_class(name, entry)}", color:)
  end

  def hl_color_class(name, model)
    "__hl_#{name}_#{model.id}"
  end

  def hl_inline_class(name, model)
    id = model.respond_to?(:id) ? model.id : model
    "__hl_inline_#{name}_#{id}"
  end

  def hl_background_class(name, model)
    id = model.respond_to?(:id) ? model.id : model
    "__hl_background_#{name}_#{id}"
  end

  def icon_for_color(color, options = {})
    return unless color&.valid_attribute?(:hexcode)

    style = join_style_arguments(
      "background-color: #{color.hexcode}",
      "border-color: #{color.darken(0.5)}50",
      options[:style]
    )

    options.merge!(class: "color--preview #{options[:class]}",
                   title: color.name,
                   style:)

    content_tag(:span, " ", options)
  end

  def color_by_variable(variable)
    DesignColor.find_by(variable:)&.hexcode
  end

  def set_generic_color_for(class_name:, color:)
    mode_variables = User.current.pref.dark_color_mode? ? default_variables_dark : default_variables_light

    concat "#{class_name} { #{default_color_styles(color.hexcode)} #{mode_variables} }"
  end

  def set_background_colors_for(class_name:, color:)
    concat "#{class_name} { #{default_color_styles(color.hexcode)} }"

    if User.current.pref.dark_color_mode?
      concat "#{class_name} { #{default_variables_dark} }"
      concat "#{class_name} { #{highlighted_background_dark} }"
    else
      concat "#{class_name} { #{default_variables_light} }"
      concat "#{class_name} { #{highlighted_background_light} }"
    end
  end

  def set_foreground_colors_for(class_name:, color:)
    concat "#{class_name} { #{default_color_styles(color.hexcode)} }"

    if User.current.pref.dark_color_mode?
      concat "#{class_name} { #{default_variables_dark} }"
      concat "#{class_name} { #{highlighted_foreground_dark} }"
    else
      concat "#{class_name} { #{default_variables_light} }"
      concat "#{class_name} { #{highlighted_foreground_light} }"
    end
  end

  def default_color_styles(hex)
    color = ColorConversion::Color.new(hex)
    rgb = color.rgb
    hsl = color.hsl

    <<~CSS.squish
      --color-r: #{rgb[:r]};
      --color-g: #{rgb[:g]};
      --color-b: #{rgb[:b]};
      --color-h: #{hsl[:h]};
      --color-s: #{hsl[:s]};
      --color-l: #{hsl[:l]};
      --perceived-lightness: calc( ((var(--color-r) * 0.2126) + (var(--color-g) * 0.7152) + (var(--color-b) * 0.0722)) / 255 );
      --lightness-switch: max(0, min(calc((1/(var(--lightness-threshold) - var(--perceived-lightness)))), 1));
    CSS
  end

  def default_variables_dark
    <<~CSS.squish
      --lightness-threshold: 0.6;
      --background-alpha: 0.18;
      --lighten-by: calc(((var(--lightness-threshold) - var(--perceived-lightness)) * 100) * var(--lightness-switch));
    CSS
  end

  def default_variables_light
    <<~CSS.squish
      --lightness-threshold: 0.453;
    CSS
  end

  def highlighted_background_dark
    style = <<~CSS.squish
      color: hsl(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) + var(--lighten-by)) * 1%)) !important;
      background: rgba(var(--color-r), var(--color-g), var(--color-b), var(--background-alpha)) !important;
    CSS

    style += if User.current.pref.dark_high_contrast_theme?
               <<~CSS.squish
                 border: 1px solid hsl(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) + 10 + var(--lighten-by)) * 1%)) !important;
               CSS
             else
               <<~CSS.squish
                 border: 1px solid hsl(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) + var(--lighten-by)) * 1%)) !important;
               CSS
             end

    style
  end

  def highlighted_background_light
    style = <<~CSS.squish
      color: hsl(0deg, 0%, calc(var(--lightness-switch) * 100%)) !important;
      background: rgb(var(--color-r), var(--color-g), var(--color-b)) !important;
    CSS

    style += if User.current.pref.light_high_contrast_theme?
               <<~CSS.squish
                 border: 1px solid hsla(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) - 75) * 1%), 1) !important;
               CSS
             else
               <<~CSS.squish
                 border: 1px solid hsl(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) - 15) * 1%)) !important;
               CSS
             end

    style
  end

  def highlighted_foreground_dark
    if User.current.pref.dark_high_contrast_theme?
      <<~CSS.squish
        color: hsla(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) + 10 + var(--lighten-by)) * 1%), 1) !important;
      CSS
    else
      <<~CSS.squish
        color: hsla(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) + var(--lighten-by)) * 1%), 1) !important;
      CSS
    end
  end

  def highlighted_foreground_light
    if User.current.pref.light_high_contrast_theme?
      <<~CSS.squish
        color: hsla(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) - (var(--color-l) * 0.5)) * 1%), 1) !important;
      CSS
    else
      <<~CSS.squish
        color: hsla(var(--color-h), calc(var(--color-s) * 1%), calc((var(--color-l) - (var(--color-l) * 0.22)) * 1%), 1) !important;
      CSS
    end
  end
end
