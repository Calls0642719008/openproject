//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { FetchRequest, FetchResponse } from '@rails/request.js';

/***************************************
  MODEL
  Common methods for sprint, work_package,
  story, task, and impediment
***************************************/

// @ts-expect-error TS(2304): Cannot find name 'RB'.
RB.Model = (function ($) {
  // @ts-expect-error TS(2304): Cannot find name 'RB'.
  return RB.Object.create({

    initialize(el:any) {
      this.$ = $(el);
      this.el = el;
    },

    afterCreate(data:string, response:FetchResponse) {
      // Do nothing. Child objects may optionally override this
    },

    afterSave(data:string, response:FetchResponse) {
      let isNew;
      let result;

      isNew = this.isNew();
      // @ts-expect-error TS(2304): Cannot find name 'RB'.
      result = RB.Factory.initialize(RB.Model, data);

      this.unmarkSaving();
      this.refresh(result);

      if (isNew) {
        const id = result.$.filter('.model').attr('id');
        this.$.attr('id', id);

        this.afterCreate(data, response);
      } else {
        this.afterUpdate(data, response);
      }
    },

    afterUpdate(data:string, response:FetchResponse) {
      // Do nothing. Child objects may optionally override this
    },

    beforeSave() {
      // Do nothing. Child objects may or may not override this method
    },

    cancelEdit() {
      this.endEdit();
      if (this.isNew()) {
        this.$.hide('blind');
      }
    },

    close() {
      this.$.addClass('closed');
    },

    copyFromDialog() {
      let editors;

      if (this.$.find('.editors').length === 0) {
        editors = $("<div class='editors'></div>").appendTo(this.$);
      } else {
        editors = this.$.find('.editors').first();
      }
      editors.html('');
      editors.append($(`#${this.getType().toLowerCase()}_editor`).children('.editor'));
      this.saveEdits();
    },

    displayEditor(editor:any) {
      const self = this;
          let baseClasses;

      baseClasses = 'ui-button ui-widget ui-state-default ui-corner-all';

      editor.dialog({
        buttons: [
        {
          text: 'OK',
          class: 'button -primary',
          click() {
            self.copyFromDialog();
            $(this).dialog('close');
          },
        },
        {
          text: 'Cancel',
          class: 'button',
          click() {
            self.cancelEdit();
            $(this).dialog('close');
          },
        },
        ],
        close(e:any, ui:any) {
          if (e.type === 'click' || (e.type === 'keydown' && e.key === 'Escape')) {
            self.cancelEdit();
          }
        },
        dialogClass: `${this.getType().toLowerCase()}_editor_dialog`,
        modal: true,
        position: { my: 'center', at: 'center', of: window },
        resizable: false,
        title: (this.isNew() ? this.newDialogTitle() : this.editDialogTitle()),
      });
      editor.find('.editor').first().focus();
      $('.button').removeClass(baseClasses);
      $('.ui-icon-closethick').prop('title', 'close');
    },

    edit() {
      const editor = this.getEditor();
          const self = this;
          let maxTabIndex = 0;

      $('.stories .editors .editor').each(function (index) {
        let value;

        // @ts-expect-error TS(2345): Argument of type 'string | undefined' is not assig... Remove this comment to see the full error message
        value = parseInt($(this).attr('tabindex'), 10);

        if (maxTabIndex < value) {
          maxTabIndex = value;
        }
      });

      if (!editor.hasClass('permanent')) {
        this.$.find('.editable').each(function (this:any, index:any) {
          const field = $(this);
          const fieldId = field.attr('field_id');
          const fieldName = field.attr('fieldname');
          const fieldLabel = field.attr('fieldlabel');
          // @ts-expect-error TS(2345): Argument of type 'string | undefined' is not assig... Remove this comment to see the full error message
          const fieldOrder = parseInt(field.attr('fieldorder'), 10);
          const fieldEditable = field.attr('fieldeditable') || 'true';
          const fieldType = field.attr('fieldtype') || 'input';
          let typeId;
          let statusId;
          let input:any;

          if (fieldType === 'select') {
            // Special handling for status_id => they are dependent of type_id
            if (fieldName === 'status_id') {
              typeId = $.trim(self.$.find('.type_id .v').html());
              // when creating stories we need to query the select directly
              if (typeId === '') {
                typeId = $('#type_id_options').val();
              }
              statusId = $.trim(self.$.find('.status_id .v').html());
              input = self.findFactory(typeId, statusId, fieldName);
            } else if (fieldName === 'type_id') {
              input = $(`#${fieldName}_options`).clone(true);
              // if the type changes the status dropdown has to be modified
              input.change(function () {
                // @ts-expect-error TS(2683): 'this' implicitly has type 'any' because it does n... Remove this comment to see the full error message
                typeId = $(this).val();
                statusId = $.trim(self.$.find('.status_id .v').html());
                let newInput = self.findFactory(typeId, statusId, 'status_id');
                newInput = self.prepareInputFromFactory(newInput, fieldId, 'status_id', fieldOrder, maxTabIndex);
                // @ts-expect-error TS(2683): 'this' implicitly has type 'any' because it does n... Remove this comment to see the full error message
                newInput = self.replaceStatusForNewType(input, newInput, $(this).parent().find('.status_id').val(), editor);
              });
            } else {
              input = $(`#${fieldName}_options`).clone(true);
            }
          } else {
            input = $(document.createElement(fieldType));
          }

          input = self.prepareInputFromFactory(input, fieldId, fieldName, fieldOrder, maxTabIndex, fieldEditable);

          // Copy the value in the field to the input element
          input.val(fieldType === 'select' ? field.children('.v').first().text() : field.text());

          // Record in the model's root element which input field had the last focus. We will
          // use this information inside RB.Model.refresh() to determine where to return the
          // focus after the element has been refreshed with info from the server.
          input.focus(function (this:any) {
            self.$.data('focus', $(this).attr('name'));
          });

          input.blur(() => {
            self.$.data('focus', '');
          });

          $('<label />').attr({
            for: input.attr('id'),
          // @ts-expect-error TS(2345): Argument of type 'string | undefined' is not assig... Remove this comment to see the full error message
          }).text(fieldLabel).appendTo(editor);
          input.appendTo(editor);
        });
      }

      this.displayEditor(editor);
      this.editorDisplayed(editor);
      return editor;
    },

    findFactory(typeId:any, statusId:any, fieldName:any) {
      // Find a factory
      let newInput = $(`#${fieldName}_options_${typeId}_${statusId}`);
      if (newInput.length === 0) {
        // when no list found, only offer the default status
        // no list = combination is not valid / user has no rights -> workflow
        newInput = $(`#status_id_options_default_${statusId}`);
      }
      newInput = newInput.clone(true);
      return newInput;
    },

    prepareInputFromFactory(input:any, fieldId:any, fieldName:any, fieldOrder:any, maxTabIndex:any, fieldEditable:any) {
      input.attr('id', `${fieldName}_${fieldId}`);
      input.attr('name', fieldName);
      input.attr('tabindex', fieldOrder + maxTabIndex);
      if (fieldEditable !== 'true') {
        input.attr('disabled', true);
      }
      input.addClass(fieldName);
      input.addClass('editor');
      input.removeClass('template');
      input.removeClass('helper');
      return input;
    },

    replaceStatusForNewType(input:any, newInput:any, statusId:any, editor:any) {
      // Append an empty field and select it in case the old status is not available
      newInput.val(statusId); // try to set the status
      if (newInput.val() !== statusId) {
          newInput.append(new Option('', ''));
          newInput.val('');
      }
      newInput.focus(function (this:any) {
        // @ts-expect-error TS(2339): Property '$' does not exist on type 'Window & type... Remove this comment to see the full error message
        self.$.data('focus', $(this).attr('name'));
      });

      newInput.blur(() => {
        // @ts-expect-error TS(2339): Property '$' does not exist on type 'Window & type... Remove this comment to see the full error message
        self.$.data('focus', '');
      });
      // Find the old status dropdown and replace it with the new one
      input.parent().find('.status_id').replaceWith(newInput);
    },

    // Override this method to change the dialog title
    editDialogTitle() {
      return `Edit ${this.getType()}`;
    },

    editorDisplayed(editor:any) {
      // Do nothing. Child objects may override this.
    },

    endEdit() {
      this.$.removeClass('editing');
    },

    error(responseHtml:string, error:unknown) {
      this.markError();
      // @ts-expect-error TS(2304): Cannot find name 'RB'.
      RB.Dialog.msg($(responseHtml).find('.errors').html());
      this.processError(responseHtml, error);
    },

    getEditor() {
      let editorId;
       let editor;

      // Create the model editor if it does not yet exist
      editorId = `${this.getType().toLowerCase()}_editor`;

      editor = $(`#${editorId}`).html('');

      if (editor.length === 0) {
        editor = $(`<div id='${editorId}'></div>`).appendTo('body');
      }
      return editor;
    },

    getID() {
      return this.$.children('.id').children('.v').text();
    },

    getType() {
      throw new Error('Child objects must override getType()');
    },

    handleClick(e:any) {
      const field = $(this);
      const model = field.parents('.model').first().data('this');
      const j = model.$;

      if (!j.hasClass('editing')
          && !j.hasClass('dragging')
          && !j.hasClass('prevent_edit')
          && !$(e.target).hasClass('prevent_edit')
          && e.target.closest('.editable').getAttribute('fieldeditable') !== 'false') {
        const editor = model.edit();
        const input = editor.find(`.${$(e.currentTarget).attr('fieldname')}.editor`);

        input.focus();
        input.click();
      }
    },

    handleSelect(e:any) {
      const j = $(this);
          const self = j.data('this');

      if (!$(e.target).hasClass('editable')
          && !$(e.target).hasClass('checkbox')
          && !j.hasClass('editing')
          && e.target.tagName !== 'A'
          && !j.hasClass('dragging')) {
        self.setSelection(!self.isSelected());
      }
    },

    isClosed() {
      return this.$.hasClass('closed');
    },

    isNew() {
      return this.getID() === '';
    },

    markError() {
      this.$.addClass('error icon icon-bug');
    },

    markIfClosed() {
      throw new Error('Child objects must override markIfClosed()');
    },

    markSaving() {
      this.$.addClass('ajax-indicator');
    },

    // Override this method to change the dialog title
    newDialogTitle() {
      return `New ${this.getType()}`;
    },

    open() {
      this.$.removeClass('closed');
    },

    processError(responseHtml:string, error:unknown) {
      // Override as needed
    },

    refresh(obj:any) {
      this.$.html($(obj.el).filter('.model').html());

      if (obj.$.length > 1) {
        // execute script tags, that were attached to the sources
        obj.$.filter('script').each(function (this:any) {
          try {
            $.globalEval($(this).html());
          } catch (e) {
          }
        });
      }

      if (obj.isClosed()) {
        this.close();
      } else {
        this.open();
      }

      this.refreshed();
    },

    refreshed() {
      // Override as needed
    },

    saveDirectives() {
      throw new Error('Child object must implement saveDirectives()');
    },

    saveEdits() {
      const j = this.$;
      const self = this;
      const editors = j.find('.editor');

      // Copy the values from the fields to the proper html elements
      editors.each(function (this:any, index:any) {
        const editor = $(this).find('input,select,textarea').addBack('input,select,textarea');
        const fieldName = editor.attr('name');
        const tagName = editor.prop('tagName');
        if (tagName === 'SELECT') {
          // if the user changes the type and that type does not offer the status
          // of the current story, the status field is set to blank
          // if the user saves this edit we will receive a validation error
          // the following 3 lines will prevent the override of the status id
          // otherwise we would loose the status id of the current ticket
          if (!(fieldName === 'status_id' && editor.val() === '')) {
            j.children(`div.${fieldName}`).children('.v').text(editor.val());
          }
          let text = editor.children(':selected').text().trim();
          if (fieldName === 'type_id') {
            text += ':';
          }

          j.children(`div.${fieldName}`).children('.t').text(text);
        } else {
          j.children(`div.${fieldName}`).text(editor.val());
        }
      });

      // Mark the work_package as closed if so
      self.markIfClosed();

      // Get the save directives.
      const { method, url, data } = self.saveDirectives();

      self.beforeSave();
      self.unmarkError();
      self.markSaving();

      (async () => {
        try {
          const request = new FetchRequest(method, url, {
            body: data,
            contentType: 'multipart/form-data',
            responseKind: 'html',
          });
          const response = await request.perform();
          const html = await response.html;
          if (!response.ok) {
            self.error(html, null);
          } else {
            self.afterSave(html, response);
          }
        } catch (error) {
          self.error('Network error', error);
        } finally {
          self.endEdit();
        }
      })();
    },

    unmarkError() {
      this.$.removeClass('error icon icon-bug');
    },

    unmarkSaving() {
      this.$.removeClass('ajax-indicator');
    },
  });
}(jQuery));
