/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { ApplicationController } from 'stimulus-use';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { renderStreamMessage } from '@hotwired/turbo';

export default class RequirePasswordConfirmationController extends ApplicationController {
  private formListener:(evt:SubmitEvent) => unknown = this.onFormSubmit.bind(this);
  private dialogCloseListener:(evt:Event) => unknown = this.onDialogClose.bind(this);
  private dialogSubmitListener:(evt:CustomEvent) => unknown = this.onConfirmationSubmit.bind(this);

  private pathHelper:PathHelperService;

  private activeDialog = false;
  private submitButton:HTMLButtonElement|null;
  private submitDialogId:string|undefined;
  private previousSubmitter:HTMLElement|null;

  async connect() {
    super.connect();

    const context = await window.OpenProject.getPluginContext();
    this.pathHelper = context.services.pathHelperService;

    this.element.addEventListener('submit', this.formListener);
    document.addEventListener('password-confirmation-dialog:close', this.dialogCloseListener);
    document.addEventListener('password-confirmation-dialog:submit', this.dialogSubmitListener);

    this.submitButton = this.element.querySelector("button[type='submit']");
    this.submitDialogId = this.submitButton?.dataset?.submitDialogId;
    this.removeSubmitDialogId();
  }

  disconnect() {
    super.disconnect();

    this.element.removeEventListener('submit', this.formListener);
    document.removeEventListener('password-confirmation-dialog:close', this.dialogCloseListener);
    document.removeEventListener('password-confirmation-dialog:submit', this.dialogSubmitListener);
  }

  private onDialogClose(_event:Event) {
    this.activeDialog = false;
  }

  private async onFormSubmit(event:SubmitEvent) {
    const passwordConfirm = this.element.querySelector('#hidden_password_confirmation');

    if (passwordConfirm !== null) {
      return true;
    }

    event.preventDefault();
    this.previousSubmitter = event.submitter;

    // If already opened, do not open another dialog
    if (this.activeDialog) {
      return false;
    }
    this.activeDialog = true;

    void fetch(this.pathHelper.myPasswordConfirmationDialogPath(), {
      method: 'GET',
      headers: {
        Accept: 'text/vnd.turbo-stream.html',
        'X-Authentication-Scheme': 'Session',
      },
    }).then((response) => {
      const contentType = response.headers.get('Content-Type') ?? '';
      const isTurboStream = contentType.includes('text/vnd.turbo-stream.html');

      if (!isTurboStream) {
        return Promise.reject(new Error('Response is not a Turbo Stream'));
      }

      return response.text();
    }).then((html) => {
      renderStreamMessage(html);
    }).catch(() => {
      this.activeDialog = false;
    });

    return false;
  }

  private onConfirmationSubmit(event:CustomEvent) {
    if(!this.activeDialog) {
      return;
    }

    const form = this.element as HTMLFormElement;
    const input = document.createElement('input');
    input.type = 'hidden';
    input.id = 'hidden_password_confirmation';
    input.name = '_password_confirmation';
    input.value = event.detail as string;

    this.addSubmitDialogId();

    form.append(input);
    form.requestSubmit(this.previousSubmitter);
  }

  private removeSubmitDialogId() {
    // Avoid that Primer dialogs already close and thus get destroyed on submit.
    // Otherwise the new form submit will not work after password confirmation
    if (this.submitButton && this.submitDialogId) {
      this.submitButton.removeAttribute('data-submit-dialog-id');
    }
  }

  private addSubmitDialogId() {
    if (this.submitButton && this.submitDialogId) {
      this.submitButton.setAttribute('data-submit-dialog-id', this.submitDialogId);
    }
  }
}
