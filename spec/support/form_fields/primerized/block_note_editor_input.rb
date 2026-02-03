# frozen_string_literal: true

module FormFields
  module Primerized
    class BlockNoteEditorInput
      include Capybara::DSL

      def open_command_dialog
        send_keys_to_editor("/")
      end

      def open_add_image_dialog
        send_keys_to_editor("/image")
        send_keys(:enter)
      end

      def open_add_work_package_dialog
        send_keys_to_editor("/work package")
        send_keys(:enter)
      end

      def fill_in(content)
        send_keys_to_editor(content)
      end

      def attach_file(path)
        input = shadow_root.find("input[type='file']", visible: false)
        input.attach_file(path, make_visible: true)
      end

      def content
        # capybara does not yet support getting content directly
        # on shadow roots
        page.evaluate_script(<<~JS)
          document.querySelector('op-block-note')
            .shadowRoot
            .innerHTML;
        JS
      end

      def shadow_root
        page.find("op-block-note").shadow_root
      end

      def element
        shadow_root.find("div[role='textbox']")
      end

      private

      # Attention: This only works with selenium, not with cuprite,
      # as cuprite does not support shadow dom (yet).
      def send_keys_to_editor(keys)
        element.send_keys(keys)
      end
    end
  end
end
