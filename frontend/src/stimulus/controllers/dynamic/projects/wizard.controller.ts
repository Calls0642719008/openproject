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

import { Controller } from '@hotwired/stimulus';
import { TurboRequestsService } from 'core-app/core/turbo/turbo-requests.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';

export default class WizardController extends Controller {
  private currentFieldId:string|null = null;

  private turboRequests:TurboRequestsService;
  private pathHelper:PathHelperService;
  private currentProject:CurrentProjectService;

  // eslint-disable-next-line @typescript-eslint/no-misused-promises
  async connect() {
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
    this.pathHelper = context.services.pathHelperService;
    this.currentProject = context.services.currentProject;
  }

  handleFieldFocus(event:FocusEvent):void {
    const field = event.target as HTMLElement;
    const customFieldId = this.extractCustomFieldId(field);

    if (customFieldId && customFieldId !== this.currentFieldId) {
      void this.updateHelpText(customFieldId);
      this.currentFieldId = customFieldId;
    }
  }

  private extractCustomFieldId(field:HTMLElement):string|null {
    const wrapperElement = field.closest<HTMLElement>('[data-custom-field-id]');

    if (wrapperElement) {
      return wrapperElement.dataset.customFieldId ?? null;
    }

    return null;
  }

  private updateHelpText(customFieldId:string) {
    const url = this.pathHelper.projectCreationWizardHelpTextPath(this.currentProject.identifier!, customFieldId);
    void this.turboRequests.requestStream(url);
  }
}
