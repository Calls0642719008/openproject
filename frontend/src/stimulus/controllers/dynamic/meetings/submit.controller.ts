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

import { ApplicationController, useMeta } from 'stimulus-use';
import { TurboRequestsService } from 'core-app/core/turbo/turbo-requests.service';
import { BeforeunloadController } from '../../beforeunload.controller';
import { appendCollapsedState } from '../../../helpers/meetings-helpers';
import { hasUnsavedChanges } from '../../../helpers/meetings-helpers';

export default class extends ApplicationController {
  private turboRequests:TurboRequestsService;
  private beforeUnloadController:BeforeunloadController;
  private boundBeforeUnloadHandler = this.beforeUnloadHandler.bind(this);

  static metaNames = ['csrf-token'];

  declare readonly csrfToken:string;

  private isSubmittingOutcomeForm = false;

  connect():void {
    useMeta(this, { suffix: false });

    window.addEventListener('beforeunload', this.boundBeforeUnloadHandler);
    this.beforeUnloadController = this.application.getControllerForElementAndIdentifier(document.body, 'beforeunload') as BeforeunloadController;

    void this.initializeTurboRequests();
  }

  private async initializeTurboRequests():Promise<void> {
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
  }

  interceptOutcomeFormSubmission(event:SubmitEvent):void {
    event.preventDefault();

    if (this.isSubmittingOutcomeForm) {
      return;
    }

    const form = event.target as HTMLFormElement;
    const outcomeContainer = form.closest('.op-meeting-agenda-item--outcomes');

    const otherOpenForms = outcomeContainer ? Array.from(outcomeContainer.querySelectorAll('form.meeting-agenda-item-outcome-form')).filter((f) => f !== form) : [];

    if (otherOpenForms.length > 0) {
      if (!window.confirm(I18n.t('js.text_are_you_sure_to_cancel'))) {
        return;
      }
    }

    this.isSubmittingOutcomeForm = true;

    void this.turboRequests.request(form.action, {
      method: form.method.toUpperCase(),
      headers: {
        'X-CSRF-Token': this.csrfToken,
        Accept: 'text/vnd.turbo-stream.html',
      },
      body: new FormData(form),
    }).finally(() => {
      this.isSubmittingOutcomeForm = false;
    });
  }

  intercept(event:Event):void {
    event.preventDefault();

    const target = event.currentTarget as HTMLElement;

    const confirmMessage = target.dataset.confirmMessage;
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return;
    }

    const url = new URL(target.dataset.href!, window.location.origin);
    const method = target.dataset.method! || 'PUT';

    appendCollapsedState(url.searchParams);

    this.handleClick(url.toString(), method);
  }

  private handleClick(url:string, method:string):void {
    if (hasUnsavedChanges()) {
      if (window.confirm(I18n.t('js.text_are_you_sure_to_cancel'))) {
        window.OpenProject.pageState = 'pristine';
        this.sendRequest(url, method);
      }
    } else {
      this.sendRequest(url, method);
    }
  }

  private beforeUnloadHandler(event:BeforeUnloadEvent):void {
    if (hasUnsavedChanges()) {
      event.preventDefault();
    }
  }

  private sendRequest(url:string, method:string):void {
    void this.turboRequests.request(url, {
      method: method,
      headers: {
        'X-CSRF-Token': this.csrfToken,
        Accept: 'text/vnd.turbo-stream.html',
      },
    });
  }

  disconnect():void {
    window.removeEventListener('beforeunload', this.boundBeforeUnloadHandler);
    super.disconnect();
  }
}
