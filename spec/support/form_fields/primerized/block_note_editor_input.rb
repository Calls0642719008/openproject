# frozen_string_literal: true

module FormFields
  module Primerized
    class BlockNoteEditorInput
      include Capybara::DSL

      def open_add_image_dialog
        send_keys_to_editor("/image")
        send_keys_to_editor(:enter)
      end

      def open_command_dialog
        send_keys_to_editor("/")
      end

      def fill_in_with_content(content)
        send_keys_to_editor(content)
      end

      def text
        page.evaluate_script(<<~JS)
          document.querySelector('op-block-note')
            .shadowRoot.querySelector('div[role="textbox"]')
            .textContent;
        JS
      end

      def content
        page.evaluate_script(<<~JS)
          document.querySelector('op-block-note')
            .shadowRoot
            .innerHTML;
        JS
      end

      private

      def send_keys_to_editor(keys)
        page.execute_script(<<~JS, keys.to_s)
          const editor = document.querySelector('op-block-note')
            .shadowRoot.querySelector('div[role="textbox"]');

          editor.focus();

          const text = arguments[0];
          if (text === 'enter') {
            editor.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))
          } else {
            document.execCommand('insertText', false, text);
            editor.dispatchEvent(new Event('change', {bubbles: true}));
          }
        JS
      end
    end
  end
end
