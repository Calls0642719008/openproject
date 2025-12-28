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
import { renderStreamMessage } from '@hotwired/turbo';
import { HttpErrorResponse } from '@angular/common/http';
import { TurboHelpers } from 'core-turbo/helpers';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';

export default class AsyncJobDialogController extends ApplicationController {
    static values = {
        closeDialogId: String,
    };

    declare closeDialogIdValue:string;
    protected pathHelper:PathHelperService;

    // eslint-disable-next-line @typescript-eslint/no-misused-promises
    async connect(){
        const context = await window.OpenProject.getPluginContext();
        this.pathHelper = context.services.pathHelperService;
        this.element.addEventListener('click', (e) => {
            e.preventDefault();
            TurboHelpers.showProgressBar();
            this.closePreviousDialog();
            this.requestJob()
                .then((job_id) => {
                    if (job_id) {
                        return this.showJobModal(job_id);
                    }
                    this.handleError(I18n.t('js.no_job_id'));
                    return null;
                })
                .catch((error:unknown) => {
                    this.handleError(error);
                })
                .finally(() => {
                    TurboHelpers.hideProgressBar();
                });
        });
    }

    closePreviousDialog() {
        if (!this.closeDialogIdValue) {
            return; // No dialog ID specified, nothing to close
        }
        const dialog = document.getElementById(this.closeDialogIdValue) as HTMLDialogElement | undefined;
        dialog?.close();
    }

    async requestJob():Promise<string> {
        const response = await fetch(this.href, {
            method: this.method,
            headers: { Accept: 'application/json' },
            credentials: 'same-origin',
        });
        if (!response.ok) {
            throw new Error(`HTTP ${response.status.toString()}: ${response.statusText}`);
        }
        const result = await response.json() as { job_id:string };
        if (!result.job_id) {
            throw new Error(I18n.t('js.invalid_job_response'));
        }
        return result.job_id;
    }

    async showJobModal(job_id:string) {
        const response = await fetch(this.pathHelper.jobStatusModalPath(job_id), {
            method: 'GET',
            headers: { Accept: 'text/vnd.turbo-stream.html' },
        });
        if (response.ok) {
            renderStreamMessage(await response.text());
        } else {
            throw new Error(response.statusText);
        }
    }

    handleError(error:unknown):void {
        void window.OpenProject.getPluginContext().then((pluginContext) => {
            pluginContext.services.notifications.addError(error as string | HttpErrorResponse);
        });
    }

    get href() {
        return (this.element as HTMLLinkElement).href;
    }

    get method() {
        return (this.element as HTMLLinkElement).dataset.jobHrefMethod ?? 'GET';
    }
}
